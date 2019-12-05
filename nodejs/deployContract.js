let Web3 = require("web3");
var fs = require('fs');

provider = new Web3.providers.HttpProvider('http://xxx.xxx.xxx.xxx:xxxx', 5000, 'user', 'Abcd@1234');
var web3 = new Web3(provider);
console.log(web3.isConnected());
var account = web3.eth.accounts[0];
web3.eth.defaultAccount = account;
web3.personal.unlockAccount(account, "", 300);

// abi for contract
var abi = JSON.parse(fs.readFileSync("../contract/build/traceability_sol_traceability.abi"));
var bytecode = "0x" + fs.readFileSync('../contract/build/traceability_sol_traceability.bin');
var address = ""
var simpleContract = web3.eth.contract(abi);
var simple = simpleContract.new({
 from: account,
 data: bytecode,
 gas: 0x47b760
}, function(e, contract) {
 if (e) {
     console.log("err creating contract", e);
 } else {
     if (!contract.address) {
         console.log("Contract transaction send: TransactionHash: " + contract.transactionHash + " waiting to be mined...");
     } else {
         console.log("Contract mined! Address: " + contract.address);
         address = contract.address
         console.log(contract);
     }
 }
});