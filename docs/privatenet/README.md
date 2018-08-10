
# Creating a Private Ethereum Network

Instructions on how to setup a private Ethereum network on virtual machines for
development and testing purposes. Each VM can join the network as a full node,
and optionally become a miner.

The network ID in this example it is set to 6789.

## Instructions

The following steps must be executed on every VM that wants to join the network.

1. Download latest Geth stable package (with tools) from the Geth download page
   [1] into a temporary location in the VM, extract its contents, and and move
   Geth executable and tools (`geth`, `bootnode`, etc.) to (`/usr/local/bin`).

1. Create a directory for the network files called `~/etherpriv` and copy the
   genesis file (`genesis.json`) into it.

1. Initialize the genesis block:

   ```
   $ geth init ~/etherpriv/genesis.json --datadir ~/etherpriv
   ```

1. If this is a node joining an existing network, create a file with a list of
   other known nodes in `~/etherpriv/static-nodes.json`, as in the following
   example:

   ```
   [
   "enode://xxxxxxxxx@[1.1.1.1]:30303",
   "enode://yyyyyyyyy@[2.2.2.2]:30303"
   ]
   ```

1. Start a full Ethereum node:

   ```
   $ geth --datadir ~/etherpriv --networkid 6789 --syncmode full
   ```

1. In another session or terminal on the same VM, attach a console to the
   running Geth process via IPC:

   ```
   $ geth attach ipc:./etherpriv/geth.ipc
   ```

1. On the console, check the node's peers:

   ```
   > admin.peers
   ```

1. (optional) In order to enable mining, setup a new account on the console
   providing a password, set it as the etherbase account so that the mining
   reward goes to this account, and start the miner (with one thread):

   ```
   > personal.newAccount("Password123")
   "0x0123456789012345678901234567890123456789"
   > eth.accounts
   ["0x0123456789012345678901234567890123456789"]
   > miner.setEtherbase(eth.accounts[0])
   true
   > eth.getBalance(eth.coinbase)
   0
   > miner.start(1)
   null
   > eth.getBalance(eth.coinbase)
   764843750000000000000
   ```

1. Once the etherbase account is setup for mining, the node can be restarted
   at any time with mining enabled using `--mine` (in order to reduce CPU usage,
   also use `--minerthreads 1`); to restrict CPU usage even more, consider
   installing and using `cpulimit` ; finally, also consider starting it with
   `nohup` to run it as an independent background process, writing the log to a
   file, e.g.:

   ```
   $ nohup cpulimit -l 10 geth --datadir ~/etherpriv --networkid 6789 --syncmode full --mine --minerthreads 1 >> ~/etherpriv/geth.log 2>&1 &
   ```

## Useful commands

The following commands can be executed on the console attached to the node
process via IPC.

1. Check if the process is mining:

   ```
   > eth.mining
   true
   ```

1. Get the current gas price:

   ```
   > eth.gasPrice
   18000000000
   ```

1. Check if the process is mining:

   ```
   > eth.blockNumber
   1876
   ```

1. Create a new account:

   ```
   > personal.newAccount("Password123")
   "0x0123456789abcdef0123456789abcdef01234567"
   ```

1. List registered accounts:

   ```
   > personal.listAccounts
   ["0xfedcba9876543210fedcba9876543210fedcba98", "0x0123456789abcdef0123456789abcdef01234567"]
   ```

1. Check balance of an account:

   ```
   > eth.getBalance("0x0123456789abcdef0123456789abcdef01234567")
   0
   ```

1. Unlock an account:

   ```
   > personal.unlockAccount("0xfedcba9876543210fedcba9876543210fedcba98")
   Unlock account 0xfedcba9876543210fedcba9876543210fedcba98
   Passphrase: <type password>
   true
   ```

1. Send transaction and check balance (after a new block has been mined):

   ```
   > eth.sendTransaction({from: "0xfedcba9876543210fedcba9876543210fedcba98", to: "0x0123456789abcdef0123456789abcdef01234567", value: 1000})
   <transaction ID>
   > eth.getBalance("0x0123456789abcdef0123456789abcdef01234567")
   1000
   ```

## Links

1. https://ethereum.github.io/go-ethereum/downloads

## References

* Chapter 9, [Introducing Ethereum and Solidity](http://solidity.eth.guide)
* [Mastering Blockchain](https://www.packtpub.com/big-data-and-business-intelligence/mastering-blockchain)
* https://github.com/chrisdannen/Introducing-Ethereum-and-Solidity/blob/master/genesis765.json
* https://github.com/ethereum/go-ethereum/wiki/Private-network
* https://github.com/ethereum/go-ethereum/wiki/Setting-up-private-network-or-local-cluster
* https://ethereum.stackexchange.com/questions/2376/what-does-each-genesis-json-parameter-mean#2377
