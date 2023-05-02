// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Proxy contract for a puzzlebox.
contract PuzzleBoxProxy {
    event Lock(bytes4 selector, bool isLocked);

    PuzzleBox private immutable _logic;
    mapping (bytes4 selector => bool isLocked) public isFunctionLocked;
    address public owner;

    constructor(PuzzleBox logic) {
        _logic = logic;
        owner = msg.sender;
    }

    // Allow/disallow a function selector from being called.
    function lock(bytes4 selector, bool isLocked)
        external
    {
        require(msg.sender == owner, 'not owner');
        isFunctionLocked[selector] = isLocked;
        emit Lock(selector, isLocked);
    }

    fallback(bytes calldata callData)
        external
        payable
        returns (bytes memory returnData)
    {
        require(!isFunctionLocked[msg.sig], 'function is locked');
        bool s;
        (s, returnData) = address(_logic).delegatecall(callData);
        if (!s) {
            assembly { revert(add(returnData, 0x20), mload(returnData)) }
        }
    }
}

// Logic contract for a puzzlebox.
contract PuzzleBox {
    event Operate(address operator);
    event Drip(uint256 dripId, uint256 fee);
    event Spread(uint256 amount, uint256 remaining);
    event Zip();
    event Torch(uint256[] dripIds);
    event Burned(uint256 dripId);
    event Creep();
    event Open(address winner);

    bool public isInitialized;
    address public admin;
    address payable public operator;
    bytes32 public friendshipHash;
    uint256 public lastDripId;
    uint256 public dripCount;
    uint256 public dripFee;
    uint256 public leakCount;
    mapping (uint256 dripId => bool isValid) public isValidDripId;
    mapping (bytes signature => uint256 blockNumber) public signatureConsumedAt;

    modifier onlyAdmin() {
        require(admin == address(0) || msg.sender == admin, 'not admin');
        _;
    }

    modifier noContractCaller() {
        require(msg.sender.code.length == 0, 'cannot be called by a contract');
        _;
    }

    modifier operation() {
        require(msg.sender == operator, 'only current operator');
        _;
        operator = payable(address(uint160(0xDEAD)));
    }

    modifier maxDripCount(uint256 maxDripped) {
        require(dripCount <= maxDripped, 'too much outstanding drip');
        _;
    }

    modifier minTotalDripped(uint256 minTotal) {
        require(lastDripId >= minTotal, 'not enough dripped');
        _;
    }

    modifier maxCallDataSize(uint256 maxBytes) {
        require(msg.data.length <= maxBytes, 'call data too large');
        _;
    }
    
    modifier maxBalance(uint256 max) {
        require(address(this).balance <= max, 'puzzlebox has too much balance');
        _;
    }

    modifier burnDripId(uint256 dripId) {
        _burnDrip(dripId);
        _;
    }

    function initialize(
        uint256 initialDripFee,
        address payable[] calldata friends,
        uint256[] calldata friendsCutBps,
        uint256 adminSigNonce,
        bytes calldata adminSig
    )
        external
        payable
    {
        require(!isInitialized, 'already initialized');
        isInitialized = true;
        dripFee = initialDripFee;
        befriend(friends, friendsCutBps);
        admin = _consumeSignature(bytes32(adminSigNonce), adminSig);
        operator = payable(address(0));
    }

    // Register fee recipient and cut (in bps) for spread().
    function befriend(
        address payable[] calldata friends,
        uint256[] calldata friendsCutBps
    )
        public
        onlyAdmin
    {
        friendshipHash = _getFriendshipHash(friends, friendsCutBps);
    }

    // Become the operator for drip() and receive this contract's entire balance.
    function operate()
        external
        noContractCaller
    {
        require(operator == address(0), 'already being operated');
        operator = payable(msg.sender); 
        _transferEth(operator, address(this).balance);
        emit Operate(operator);
    }
   
    // Mint drips for an exponentially increasing fee.
    function drip()
        external payable
        operation
        returns (uint256 dripId)
    {
        require(msg.value >= dripFee, 'insufficient fee');
        // Refund excess.
        if (msg.value > dripFee) {
            _transferEth(payable(msg.sender), msg.value - dripFee);
        }
        // Drip.
        ++dripCount;
        dripId = ++lastDripId;
        isValidDripId[dripId] = true;
        emit Drip(dripId, dripFee);
        // Double fee for next drip.
        dripFee *= 2;
    }

    // Pay out a portion of accumulated fees to friends set by befriend().
    function spread(
        address payable[] calldata friends,
        uint256[] calldata friendsCutBps
    )
        external
        burnDripId(3)
    {
        require(friendshipHash == _getFriendshipHash(friends, friendsCutBps), 'not my friends');
        uint256 total = 0;
        for (uint256 i; i < friends.length; ++i) {
            uint256 feeBps = friendsCutBps[i] > 1e4 ? 1e4 : friendsCutBps[i];
            uint256 amount = feeBps * address(this).balance / 1e4;
            total += amount;
            _transferEth(friends[i], amount);
        }
        emit Spread(total, address(this).balance);
    }

    // Perform a gas constrained call to leak().
    function zip()
        external
        burnDripId(1)
    {
        this.leak{gas: 12_000}();
        emit Zip();
    }

    function leak()
        external
    {
        unchecked {
            payable(address(uint160(address(this)) + uint160(++leakCount))).transfer(1);
        }
    }

    // Burn an encoded list of drip IDs.
    function torch(bytes calldata encodedDripIds)
        external
        burnDripId(5)
        maxCallDataSize(300)
    {
        uint256[] memory dripIds = abi.decode(encodedDripIds, (uint256[]));
        for (uint256 i; i < dripIds.length; ++i) {
            _burnDrip(dripIds[i]);
        }
        emit Torch(dripIds);
    }

    // Recursively calls creepForward().
    function creep()
        external
        burnDripId(10)
    {
        // Succeed only if creepForward is called 7 times.
        require(this.creepForward{value: address(this).balance}() == 7, 'too creepy');
        emit Creep();
    }

    function creepForward()
        external payable
        returns (uint256 count)
    {
        unchecked {
            count = 1;
            if (msg.value != 0) {
                try this.creepForward{value: msg.value - 1}() returns (uint256 count_) {
                    count += count_;
                } catch {}
            }
        }
    }

    // Consume an unused signature generated by the admin and open the box.
    function open(uint256 nonce, bytes calldata adminSig)
        external
        maxBalance(0)
        maxDripCount(0)
        minTotalDripped(10)
    {
        require(admin == _consumeSignature(bytes32(nonce), adminSig), 'not signed by admin');
        // Congrats ;-)
        emit Open(msg.sender);
    }

    function _consumeSignature(bytes32 h, bytes memory sig)
        internal
        returns (address signer)
    {
        require(signatureConsumedAt[sig] == 0, 'signature already used');
        signatureConsumedAt[sig] = block.number;
        signer = _recoverPackedSignature(h, sig);
    }

    function _recoverPackedSignature(bytes32 h, bytes memory sig)
        internal
        pure
        returns (address)
    {
        require(sig.length == 65, 'invalid packed signature');
        // unpack signature into r, s, v components
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := shr(248, mload(add(sig, 0x60)))
        }
        return ecrecover(h, v, r, s);
    }

    function _transferEth(address payable to, uint256 amount)
        private
    {
        (bool s,) = to.call{value: amount}("");
        require(s, 'transfer failed');
    }
    
    function _burnDrip(uint256 dripId)
        internal
    {
        require(isValidDripId[dripId], 'missing drip id');
        isValidDripId[dripId] = false;
        --dripCount;
        emit Burned(dripId);
    }

    function _getFriendshipHash(
        address payable[] calldata friends,
        uint256[] calldata friendsBps
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked('fees', friends, friendsBps));
    }
}

// Contract for instantiating puzzleboxes.
contract PuzzleBoxFactory {
    PuzzleBox public immutable logic = new PuzzleBox();

    function createPuzzleBox()
        external
        payable
        returns (PuzzleBox puzzle)
    {
        PuzzleBoxProxy proxy = new PuzzleBoxProxy(logic);
        proxy.lock(PuzzleBox.torch.selector, true);
        puzzle = PuzzleBox(payable(proxy));
        {
            address payable[] memory friends = new address payable[](2);
            uint256[] memory friendsCutBps = new uint256[](friends.length);
            friends[0] = payable(0x416e59DaCfDb5D457304115bBFb9089531D873B7);
            friends[1] = payable(0xC817dD2a5daA8f790677e399170c92AabD044b57);
            friendsCutBps[0] = 0.015e4;
            friendsCutBps[1] = 0.0075e4;
            puzzle.initialize{value: 1337}(
                // initialDripFee
                100,
                friends,
                friendsCutBps,
                // adminSigNonce
                0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8,
                // adminSig
                (
                    hex"c8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8"
                    hex"625cb970c2768fefafc3512a3ad9764560b330dcafe02714654fe48dd069b6df"
                    hex"1c"
                )
            );
        }
    }
}
