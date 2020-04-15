const exchangeAddress = "0x82ae8b06c54b2d5f0da4a830be135c805f737c5e";
var account = ""
var tokenContract;
var token;

// if (typeof web3 !== 'undefined') {
// 	web3 = new Web3(web3.currentProvider);
// } else {
// 	// set the provider you want from Web3.providers
// 	//web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:7545'));
// 	web3 = new Web3(new Web3.providers.HttpProvider('ropsten.infura.io/v3/f3ab86b731254c00a0f43aeb72b7c0c3'));
// }

window.addEventListener('load', async () => {
    // Modern dapp browsers...
    if (window.ethereum) {
        window.web3 = new Web3(ethereum);
        try {
            // Request account access if needed
            await ethereum.enable();
            account = web3.eth.accounts[0];
        } catch (error) {
            // User denied account access...
        }
    }
    // Legacy dapp browsers...
    else if (window.web3) {
		web3 = new Web3(new Web3.providers.HttpProvider('ropsten.infura.io/v3/f3ab86b731254c00a0f43aeb72b7c0c3'));
		account = web3.eth.accounts[0];
    }
    // Non-dapp browsers...
    else {
        console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
    }
});

setInterval(function () {
	if (web3.eth.accounts[0] !== account) {
		account = web3.eth.accounts[0];
		updateInterface();
		refreshPage(true);
	}
}, 100);

setInterval(function () {
	refreshPage(true);
}, 20000);

var exchangeContract = web3.eth.contract([
	{
		"constant": false,
		"inputs": [
			{
				"name": "tokenAddress",
				"type": "address"
			}
		],
		"name": "addToken",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "orderId",
				"type": "bytes32"
			}
		],
		"name": "cancelOrder",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [],
		"name": "close",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_type",
				"type": "bool"
			}
		],
		"name": "matching",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_amount",
				"type": "uint256"
			},
			{
				"name": "_limit",
				"type": "uint256"
			}
		],
		"name": "place_buy_order",
		"outputs": [
			{
				"name": "success",
				"type": "bool"
			}
		],
		"payable": true,
		"stateMutability": "payable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_from",
				"type": "address"
			},
			{
				"name": "_token",
				"type": "uint256"
			},
			{
				"name": "_tokenContract",
				"type": "address"
			},
			{
				"name": "_data",
				"type": "bytes"
			}
		],
		"name": "receiveApproval",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "status",
				"type": "bool"
			}
		],
		"name": "setIsExchangeOpen",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "transferOwnership",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_tokenAddress",
				"type": "address"
			},
			{
				"name": "_to",
				"type": "address"
			},
			{
				"name": "_token",
				"type": "uint256"
			}
		],
		"name": "transferToken",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_sender",
				"type": "address"
			}
		],
		"name": "withdrawEth",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [],
		"name": "withdrawFees",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			}
		],
		"name": "withdrawToken",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"payable": true,
		"stateMutability": "payable",
		"type": "constructor"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"name": "order_id",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "token_address",
				"type": "address"
			},
			{
				"indexed": false,
				"name": "block_nr",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "order_type",
				"type": "bool"
			},
			{
				"indexed": false,
				"name": "sender",
				"type": "address"
			},
			{
				"indexed": false,
				"name": "eth_left",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "token_left",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "limit",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "executed",
				"type": "bool"
			},
			{
				"indexed": false,
				"name": "cancelled",
				"type": "bool"
			},
			{
				"indexed": false,
				"name": "previous_order",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "next_order",
				"type": "bytes32"
			}
		],
		"name": "Placed",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"name": "order_id",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "token",
				"type": "address"
			},
			{
				"indexed": false,
				"name": "eth_left",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "token_left",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "executed",
				"type": "bool"
			},
			{
				"indexed": false,
				"name": "cancelled",
				"type": "bool"
			},
			{
				"indexed": false,
				"name": "previous_order",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "next_order",
				"type": "bytes32"
			}
		],
		"name": "Updated",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": false,
				"name": "trade_id",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "token_address",
				"type": "address"
			},
			{
				"indexed": false,
				"name": "block_nr",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "trade_timestamp",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "order_type",
				"type": "bool"
			},
			{
				"indexed": false,
				"name": "buy_order_id",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "sell_order_id",
				"type": "bytes32"
			},
			{
				"indexed": false,
				"name": "trade_amount",
				"type": "uint256"
			},
			{
				"indexed": false,
				"name": "trade_price",
				"type": "uint256"
			}
		],
		"name": "Traded",
		"type": "event"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "b",
				"type": "bytes"
			}
		],
		"name": "bytesToUint",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "pure",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "eth_balance",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "fees",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "first_buy_order_id",
		"outputs": [
			{
				"name": "",
				"type": "bytes32"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "first_sell_order_id",
		"outputs": [
			{
				"name": "",
				"type": "bytes32"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "free_eth_balance",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			},
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "free_token_balance",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			}
		],
		"name": "getBestPrice",
		"outputs": [
			{
				"name": "price",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "tokenAddress",
				"type": "address"
			}
		],
		"name": "getDecimals",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "tokenAddress",
				"type": "address"
			}
		],
		"name": "getLastPrice",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getNextOrder",
		"outputs": [
			{
				"name": "",
				"type": "bytes32"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderBlockNr",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderEthLeft",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderEthPriceLimit",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderEthSent",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderSender",
		"outputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderTokenAmount",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderTokenLeft",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getOrderType",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "getPreviousOrder",
		"outputs": [
			{
				"name": "",
				"type": "bytes32"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "tokenAddress",
				"type": "address"
			}
		],
		"name": "getSymbol",
		"outputs": [
			{
				"name": "",
				"type": "string"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "pos",
				"type": "uint256"
			}
		],
		"name": "getTokenAddress",
		"outputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "getTokenListLength",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "tokenAddress",
				"type": "address"
			}
		],
		"name": "getTokenSymbol",
		"outputs": [
			{
				"name": "",
				"type": "string"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "is_token_listed",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "isOrderCancelled",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_token",
				"type": "address"
			},
			{
				"name": "_orderId",
				"type": "bytes32"
			}
		],
		"name": "isOrderExecuted",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "last_price",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "listed_tokens",
		"outputs": [
			{
				"name": "",
				"type": "string"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			},
			{
				"name": "",
				"type": "bytes32"
			}
		],
		"name": "orders",
		"outputs": [
			{
				"name": "id",
				"type": "bytes32"
			},
			{
				"name": "token_address",
				"type": "address"
			},
			{
				"name": "block_nr",
				"type": "uint256"
			},
			{
				"name": "order_type",
				"type": "bool"
			},
			{
				"name": "sender",
				"type": "address"
			},
			{
				"name": "eth_sent",
				"type": "uint256"
			},
			{
				"name": "eth_left",
				"type": "uint256"
			},
			{
				"name": "token_amount",
				"type": "uint256"
			},
			{
				"name": "token_left",
				"type": "uint256"
			},
			{
				"name": "limit",
				"type": "uint256"
			},
			{
				"name": "executed",
				"type": "bool"
			},
			{
				"name": "cancelled",
				"type": "bool"
			},
			{
				"name": "previous_order",
				"type": "bytes32"
			},
			{
				"name": "next_order",
				"type": "bytes32"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "address"
			},
			{
				"name": "",
				"type": "address"
			}
		],
		"name": "token_balance",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"name": "token_list_array",
		"outputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	}
]);
var exchange = exchangeContract.at(exchangeAddress);

//ERC20 Template from https://theethereum.wiki/w/index.php/ERC20_Token_Standard
var tokenContract = web3.eth.contract([
	{
		"constant": true,
		"inputs": [],
		"name": "name",
		"outputs": [
			{
				"name": "",
				"type": "string"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "spender",
				"type": "address"
			},
			{
				"name": "tokens",
				"type": "uint256"
			}
		],
		"name": "approve",
		"outputs": [
			{
				"name": "success",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "totalSupply",
		"outputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "from",
				"type": "address"
			},
			{
				"name": "to",
				"type": "address"
			},
			{
				"name": "tokens",
				"type": "uint256"
			}
		],
		"name": "transferFrom",
		"outputs": [
			{
				"name": "success",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "decimals",
		"outputs": [
			{
				"name": "",
				"type": "uint8"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "tokenOwner",
				"type": "address"
			}
		],
		"name": "balanceOf",
		"outputs": [
			{
				"name": "balance",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [],
		"name": "acceptOwnership",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "symbol",
		"outputs": [
			{
				"name": "",
				"type": "string"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "to",
				"type": "address"
			},
			{
				"name": "tokens",
				"type": "uint256"
			}
		],
		"name": "transfer",
		"outputs": [
			{
				"name": "success",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "spender",
				"type": "address"
			},
			{
				"name": "tokens",
				"type": "uint256"
			},
			{
				"name": "data",
				"type": "bytes"
			}
		],
		"name": "approveAndCall",
		"outputs": [
			{
				"name": "success",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "newOwner",
		"outputs": [
			{
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "tokenAddress",
				"type": "address"
			},
			{
				"name": "tokens",
				"type": "uint256"
			}
		],
		"name": "transferAnyERC20Token",
		"outputs": [
			{
				"name": "success",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "tokenOwner",
				"type": "address"
			},
			{
				"name": "spender",
				"type": "address"
			}
		],
		"name": "allowance",
		"outputs": [
			{
				"name": "remaining",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_newOwner",
				"type": "address"
			}
		],
		"name": "transferOwnership",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"payable": true,
		"stateMutability": "payable",
		"type": "fallback"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"name": "_from",
				"type": "address"
			},
			{
				"indexed": true,
				"name": "_to",
				"type": "address"
			}
		],
		"name": "OwnershipTransferred",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"name": "from",
				"type": "address"
			},
			{
				"indexed": true,
				"name": "to",
				"type": "address"
			},
			{
				"indexed": false,
				"name": "tokens",
				"type": "uint256"
			}
		],
		"name": "Transfer",
		"type": "event"
	},
	{
		"anonymous": false,
		"inputs": [
			{
				"indexed": true,
				"name": "tokenOwner",
				"type": "address"
			},
			{
				"indexed": true,
				"name": "spender",
				"type": "address"
			},
			{
				"indexed": false,
				"name": "tokens",
				"type": "uint256"
			}
		],
		"name": "Approval",
		"type": "event"
	}
]);

console.log(exchange);
