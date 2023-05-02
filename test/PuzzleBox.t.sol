// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PuzzleBox.sol";
import "../src/PuzzleBoxSolution.sol";

contract PuzzleBoxFixture is Test {
    event Lock(bytes4 selector, bool isLocked);
    event Operate(address operator);
    event Drip(uint256 dripId, uint256 fee);
    event Spread(uint256 amount, uint256 remaining);
    event Zip();
    event Creep();
    event Torch(uint256[] dripIds);
    event Burned(uint256 dripId);
    event Open(address winner);

    PuzzleBoxFactory _factory = new PuzzleBoxFactory();
    PuzzleBox _puzzle;
    PuzzleBoxSolution _solution;

    function setUp() external {
        _puzzle = _factory.createPuzzleBox{value: 1337}();
        _solution = PuzzleBoxSolution(address(new SolutionContainer(type(PuzzleBoxSolution).runtimeCode)));
    }

    function test_win() external {
        // Uncomment to verify a complete solution.
        // vm.expectEmit(false, false, false, false, address(_puzzle));
        // emit Open(address(0));
        _solution.solve(_puzzle);
    }
}

contract SolutionContainer {
    constructor(bytes memory solutionRuntime) {
        assembly {
            return(add(solutionRuntime, 0x20), mload(solutionRuntime))
        }
    }
}
