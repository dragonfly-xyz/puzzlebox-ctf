# PuzzleBox CTF

Do you have what it takes to unlock this devious solidity puzzle box? You will need to demonstrate your understanding of the EVM, solidity, and smart contract vulnerabilities and chain them together in an exact sequence to get inside, with challenges getting more difficult as you progress. How far can you get?

## Setup

```bash
# clone this repo
git clone git@github.com:merklejerk/puzzlebox-ctf.git && cd puzzlebox-ctf
# install foundry
forge install
# check your solution
forge test -vvvv
```

## Structure and Rules

The core puzzlebox contracts are in [`PuzzleBox.sol`](./src/PuzzleBox.sol). The puzzlebox is deployed as a custom proxy contract, `PuzzleBoxProxy`, which delegatecalls most logic to the `PuzzleBox` logic contract. The Puzzlebox is instantiated through the `PuzzleBoxFactory`, which is in charge of setting up initial state. 

[`PuzzleBoxSolution`](./src/PuzzleBoxSolution.sol) is a contract with an incomplete `solve()` function where you should implement your solution. The [tests](./test/PuzzleBox.t.sol) will instantiate and call this contract to verify your solution.
