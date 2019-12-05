let Web3 = require("web3");
let fs = require("fs");

let provider = new Web3.providers.HttpProvider('http://xxx.xxx.xxx.xxx:xxxx', 50000, 'user', 'Abcd@1234');
let web3 = new Web3(provider);
console.log("web3 is connected:", web3.isConnected());
let account = web3.eth.accounts[0];
web3.eth.defaultAccount = account;
web3.personal.unlockAccount(account, "", 3000);
// abi for contract
var abi = JSON.parse(fs.readFileSync("../contract/build/traceability_sol_traceability.abi"));
var contractAddress = "0x1dbaccedfe36189819d2f6029b8036f9a0ea398b";

var contract = web3.eth.contract(abi).at(contractAddress);
console.log("getBalance:", contract.getBalance().toString());

var assetName = "asset1";
var assetKeys = ["color", "weight"];
var assetValues = ["red", "0.1kg"];
contract.TokenSent({a:5}, function(error, result) {
    console.log("TokenSent event");

    if(!error) {
        
        console.log(result);
    } else {
        console.log("error:", error);
    }
});

contract.AssetCreated({}, function(error, result) {
    console.log("AssetCreated event");

    if(!error) {
        
        console.log(result);
    } else {
        console.log("error:", error);
    }
});
console.log(contract.sendToken(0xf07b2cb4d766ffa81bea15b99cd459c69b9f766a, 1*1e18));
console.log("getBalance:", contract.getBalance().toString());

// console.log("getAssetList:", contract.getAssetList());
// console.log("createAsset:", contract.createAsset(assetName, assetKeys, assetValues, {gas:30000000}));
// console.log("getCurrentAssetId:", contract.getCurrentAssetId().toString());
// console.log("getAssetInfo:", contract.getAssetInfo(0xb3a2d41842b3b53a8bf82c3aae28f6ad7a752c793715244182b7839f37f07d20));

// contract.createAsset(assetName, assetKeys, assetValues, {}, function(error, result){
//     console.log("call CreateAsset");
//     if(!error) {        
//         console.log("result:", result);
//     } else {
//         console.log("error:", error);
//     }
// });
