pragma solidity ^0.4.25;

contract Ownable {
    address public owner;


    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor() public {
        owner = msg.sender;
    }


    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }


    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}

contract ERC20Interface {

    uint8 public decimals;

    string public symbol;

    string public name;

    function totalSupply() public view returns (uint);

    function balanceOf(address tokenOwner) public view returns (uint balance);

    function allowance(address tokenOwner, address spender) public view returns (uint remaining);

    function transfer(address to, uint tokens) public returns (bool success);

    function approve(address spender, uint tokens) public returns (bool success);

    function transferFrom(address from, address to, uint tokens) public returns (bool success);


    event Transfer(address indexed from, address indexed to, uint tokens);

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}


contract _0xChange is Ownable {


    //allows to close the exchange
    bool is_exchange_open;

    //First order of the queue
    mapping(address => bytes32) public first_buy_order_id;
    mapping(address => bytes32) public first_sell_order_id;

    //mapping of all orders by order_id in uint format
    //can be reconverted to the right format using web3.toHex
    mapping(address => mapping(bytes32 => order)) public orders;
    mapping(address => uint[]) public order_list;

    //Executions records
    //(i) mapping token => execution_id => execution
    //(ii) mapping token => (uint) execution_id
    mapping(address => mapping(bytes32 => trade)) public trades;
    mapping(address => uint[]) public trade_list;

    //mapping of address with current balance with the exchange
    mapping(address => uint) public eth_balance;
    mapping(address => mapping(address => uint)) public token_balance;

    //mapping of listed tokens
    mapping(address => string) public listed_tokens;
    mapping(address => bool) public is_token_listed;
    address[] public token_list_array;

    //contrat fee rate, i.e 0.25%
    uint public fees = 25 ;
    uint private fees_pool;
    
    //Event generated when an order is placed successfully 
    event Placed(bytes32 order_id, address sender, address token_address, 
    bool order_type, uint block_nr, uint eth_sent, uint eth_left,
    uint token_amount, uint token_left, uint order_limit,
    bytes32 previous_order, bytes32 next_order);
    
    event Traded(bytes32 trade_id, address token_address, uint block_nr, 
    uint trade_timestamp, bool order_type, bytes32 buy_order_id, 
    bytes32 sell_order_id, uint exec_amount, uint trade_price);

    //Default Constructor
    constructor() public payable {
        is_exchange_open = true;
    }

    //Order struct
    struct order{
        bytes32 id;
        address token_address;
        uint block_nr;
        bool order_type;
        address from;
        uint eth_sent;
        uint eth_left;
        uint token_amount;
        uint token_left;
        uint limit;
        bool executed;
        bool cancelled;
        bytes32 previous_order;
        bytes32 next_order;
    }


    //Trade struct
    struct trade{
        bytes32 id;
        address token_address;
        uint block_nr;
        uint timestamp;
        bool order_type;
        bytes32 buy_order_id;
        bytes32 sell_order_id;
        uint exec_amount;
        uint price;
    }


    // ------------------------------------------------------------------------

    // Place an order in the orders mapping

    // The chain is organized with market order first and then 

    // Limit order sorted from highest to lowest bid

    // ------------------------------------------------------------------------

    function place_buy_order(address _token, uint _amount, uint _limit) public payable returns (bool success) {
        require(_amount * _limit / (10**uint(ERC20Interface(_token).decimals())) <= msg.value);
        require(msg.value > 0);
        require(is_exchange_open);

        bytes32 order_id = keccak256(
            abi.encodePacked(
                block.number,
                _token,
                msg.sender,
                _amount,
                _limit));

        orders[_token][order_id].id = order_id;
        orders[_token][order_id].token_address = _token;
        orders[_token][order_id].block_nr = block.number;
        orders[_token][order_id].order_type = true;
        orders[_token][order_id].from = msg.sender;
        orders[_token][order_id].eth_sent = msg.value;
        orders[_token][order_id].eth_left = msg.value;
        orders[_token][order_id].token_amount = _amount;
        orders[_token][order_id].token_left = _amount;
        orders[_token][order_id].limit = _limit;
        orders[_token][order_id].executed = false;
        orders[_token][order_id].cancelled = false;
        orders[_token][order_id].previous_order = bytes32(0);
        orders[_token][order_id].next_order = bytes32(0);

        order_list[_token].push(uint(order_id));

        insertBuyOrder(_token, order_id);
        emitOrder(_token, order_id);

        matching(_token, true);
        return true;
    }


    // ------------------------------------------------------------------------

    // Place an order in the orders mapping

    // Called internally from ReceiveApproval

    // The chain is organized with market order first and then 

    // Limit order sorted from high lowest to highes ask

    // ------------------------------------------------------------------------

    function place_sell_order(address _seller, address _token, uint _amount, uint _limit) internal returns (bool success) {
        require(is_exchange_open);

        bytes32 order_id = keccak256(
            abi.encodePacked(
                block.number,
                _token,
                msg.sender,
                _amount,
                _limit));

        orders[_token][order_id].id = order_id;
        orders[_token][order_id].token_address = _token;
        orders[_token][order_id].block_nr = block.number;
        orders[_token][order_id].order_type = false;
        orders[_token][order_id].from = _seller;
        orders[_token][order_id].eth_sent = 0;
        orders[_token][order_id].eth_left = 0;
        orders[_token][order_id].token_amount = _amount;
        orders[_token][order_id].token_left = _amount;
        orders[_token][order_id].limit = _limit;
        orders[_token][order_id].executed = false;
        orders[_token][order_id].cancelled = false;
        orders[_token][order_id].previous_order = bytes32(0);
        orders[_token][order_id].next_order = bytes32(0);

        order_list[_token].push(uint(order_id));

        insertSellOrder(_token, order_id);
        emitOrder(_token, order_id);

        matching(_token, false);
        return true;
    }


    // ------------------------------------------------------------------------

    // Match orders in the book

    // 1) Market orders are matched together using the lower of

    // the last paid price on the exchange and the lowest ask

    // 2) Limit orders are matched together until bid < ask

    // ------------------------------------------------------------------------

    function matching(address _token, bool _type) public {
        bytes32 exec_id;
        uint price;
        uint amount;
     
        while (matchingPossible(_token))
        {

            //set execution price for market vs market,
            //market vs limit order, limit vs market
            //and limit vs. limit type of order
            price = transactionPrice(_token, _type);
            amount = transactionAmount(_token, price);
            
            exec_id = keccak256(
                abi.encodePacked(
                    _token,
                    block.number,
                    _token,
                    first_buy_order_id[_token],
                    first_sell_order_id[_token],
                    price,
                    amount));

            //Build the trade
            trades[_token][exec_id].id = exec_id;
            trades[_token][exec_id].token_address = _token;
            trades[_token][exec_id].block_nr = block.number;
            trades[_token][exec_id].timestamp = block.timestamp;
            trades[_token][exec_id].order_type = _type;
            trades[_token][exec_id].buy_order_id = first_buy_order_id[_token];
            trades[_token][exec_id].sell_order_id = first_sell_order_id[_token];
            trades[_token][exec_id].exec_amount = amount;
            trades[_token][exec_id].price = price;    
 
            //Record the trades
            trade_list[_token].push(uint(exec_id));

            //Settle payment and finalize the trade
            settlement(_token, exec_id);

        }
    }


    // ------------------------------------------------------------------------

    // Compare the first orders of the bid and ask and define if

    // a matching is possible

    // ------------------------------------------------------------------------

    function matchingPossible(address _token) internal view returns (bool) {
        return (orders[_token][first_buy_order_id[_token]].limit >= orders[_token][first_sell_order_id[_token]].limit ||
        (orders[_token][first_buy_order_id[_token]].limit == 0 ||orders[_token][first_sell_order_id[_token]].limit == 0)) &&
        (first_buy_order_id[_token] != 0 && first_sell_order_id[_token] != 0);
    }


    // ------------------------------------------------------------------------

    // Return the transaction price:

    // 1) Market order vs Market order: lower of last price or best offer

    // 2) Market order vs Limit Order: limit order

    // ------------------------------------------------------------------------

    function transactionPrice(address _token, bool _type) internal view returns (uint) {

        //Market order against market order
        //We call the getBestPrice function, which returns the lowest of
        //the last trade or the best bid
        if(orders[_token][first_buy_order_id[_token]].limit == 0 &&
            orders[_token][first_sell_order_id[_token]].limit == 0) {

            return getBestPrice(_token);

        //Buy order at best vs limited sell order ==> ask price
        } else if(orders[_token][first_buy_order_id[_token]].limit == 0 &&
            orders[_token][first_sell_order_id[_token]].limit != 0) {

            return orders[_token][first_sell_order_id[_token]].limit;

        //Limited buy order vs market sell order ==> bid price
        } else if(orders[_token][first_buy_order_id[_token]].limit != 0 &&
            orders[_token][first_sell_order_id[_token]].limit == 0) {

            return orders[_token][first_buy_order_id[_token]].limit;

        //Limited buy order vs limited sell order
        // ==> limit placed by the counterparty not initiating the trade
        } else if (orders[_token][first_buy_order_id[_token]].limit != 0 &&
            orders[_token][first_sell_order_id[_token]].limit != 0) {

            if(_type)
                return orders[_token][first_sell_order_id[_token]].limit;
            else
                return orders[_token][first_buy_order_id[_token]].limit;
        }

    }


    // ------------------------------------------------------------------------

    // Return transaction amount as the lowest of the bid amount, 

    // the offer amount and the maximal amount that the buyers can aquire as

    // the ether left on the order divided by the transaction price

    // ------------------------------------------------------------------------

    function transactionAmount(address _token, uint price) internal view returns(uint) {

        return min(orders[_token][first_buy_order_id[_token]].token_left, min(
            orders[_token][first_buy_order_id[_token]].eth_left * 
            (10**uint(ERC20Interface(_token).decimals())) / price,
            orders[_token][first_sell_order_id[_token]].token_left));

    }


    // ------------------------------------------------------------------------

    // Arrange the settlement by:
    
    // 1) reducing the buy and sell order amounts by the transaction amount

    // 2) push the execution ID in the execution array of the orders

    // 3) increase the token balance of the buyer and the eth balance of

    // the seller, book the fees and emit the Execution event

    // 4) close orders that have been executed, buy amount considered executed

    // once remaining ETH is smaller than 10000000000 gwei.

    // ------------------------------------------------------------------------

    function settlement(address _token, bytes32 _exec_id) internal {

        uint trx_volume = trades[_token][_exec_id].exec_amount *
            trades[_token][_exec_id].price / 
            (10**uint(ERC20Interface(_token).decimals()));
        uint fee_payment;
        uint payment;

        //update orders
        orders[_token][first_buy_order_id[_token]].token_left -= trades[_token][_exec_id].exec_amount;
        orders[_token][first_sell_order_id[_token]].token_left -= trades[_token][_exec_id].exec_amount;
        orders[_token][first_buy_order_id[_token]].eth_left -= trx_volume;

        //Fee processing
        fee_payment = trx_volume * fees / 10000;
        payment = trx_volume - fee_payment;

        token_balance[_token][getOrderFrom(_token, trades[_token][_exec_id].buy_order_id)] += trades[_token][_exec_id].exec_amount;
        eth_balance[getOrderFrom(_token, trades[_token][_exec_id].sell_order_id)] += payment;
        fees_pool += fee_payment;

        //Consider an order as executed if the token amount left is zero
        //or if the eth amount left is smaller than 10000000000 wei (0.00000001 ETH)
        if(orders[_token][first_buy_order_id[_token]].token_left == 0 ||
            orders[_token][first_buy_order_id[_token]].eth_left < 10000000000) {

            orders[_token][first_buy_order_id[_token]].executed = true;

            eth_balance[getOrderFrom(_token, trades[_token][_exec_id].buy_order_id)] += orders[_token][first_buy_order_id[_token]].eth_left;
            orders[_token][first_buy_order_id[_token]].eth_left = 0;

            first_buy_order_id[_token] = orders[_token][first_buy_order_id[_token]].next_order;

            orders[_token][first_buy_order_id[_token]].previous_order = bytes32(0);
            orders[_token][trades[_token][_exec_id].buy_order_id].next_order = bytes32(0);
            
        }


        if(orders[_token][first_sell_order_id[_token]].token_left == 0) {

            orders[_token][first_sell_order_id[_token]].executed = true;

            first_sell_order_id[_token] = orders[_token][first_sell_order_id[_token]].next_order;

            orders[_token][first_sell_order_id[_token]].previous_order = bytes32(0);
            orders[_token][trades[_token][_exec_id].sell_order_id].next_order = bytes32(0);

        }

        emit Traded(_exec_id, _token, trades[_token][_exec_id].block_nr, 
        trades[_token][_exec_id].timestamp, trades[_token][_exec_id].order_type, 
        trades[_token][_exec_id].buy_order_id, trades[_token][_exec_id].sell_order_id, 
        trades[_token][_exec_id].exec_amount, trades[_token][_exec_id].price);

    }


    // ------------------------------------------------------------------------

    // Calculate best price for market orders by returning

    // the lower of the the last price paid or the lowest ask    

    // ------------------------------------------------------------------------

    function getBestPrice(address _token) public view returns (uint price) {
        //lowest of last paid price or lowest limit sell order
        //used to execute market orders
        bytes32 position = first_sell_order_id[_token];
        uint best_price = getLastPrice(_token);

        while(orders[_token][position].id != 0)
        {
            if(orders[_token][position].limit != 0) {
                if(orders[_token][position].limit < best_price) {
                    best_price = orders[_token][position].limit;
                }

                return best_price;
            }

            position = orders[_token][getNextOrder(_token, position)].id;
        }

    }


    // ------------------------------------------------------------------------

    // Cancel an order, remove it from the chain of orders and

    // increase eth balance of the trader by the eth left   

    // ------------------------------------------------------------------------

    function cancelOrder(address _token, bytes32 orderId) public {

        require(msg.sender == orders[_token][orderId].from);
        require(orders[_token][orderId].cancelled == false);
        require(orders[_token][orderId].executed == false);

        order memory _order = orders[_token][orderId];

        if(_order.order_type == true) {
            if(first_buy_order_id[_token] == orderId){
                first_buy_order_id[_token] = _order.next_order;
                orders[_token][_order.next_order].previous_order = _order.previous_order;
            } else {
                orders[_token][_order.previous_order].next_order = _order.next_order;
                orders[_token][_order.next_order].previous_order = _order.previous_order;
            }
        } else {
            if(first_sell_order_id[_token] == orderId){ 
                first_sell_order_id[_token] = _order.next_order;
                orders[_token][_order.next_order].previous_order = _order.previous_order;
            } else {
                orders[_token][_order.previous_order].next_order = _order.next_order;
                orders[_token][_order.next_order].previous_order = _order.previous_order;
            }
        }

        _order.previous_order = bytes32(0);
        _order.next_order = bytes32(0);

        _order.cancelled = true;

        eth_balance[_order.from] += _order.eth_left;

        _order.eth_left = 0;
        
        orders[_token][orderId] = _order;

    }

    function flush(address tokenAddress) private onlyOwner {

        bytes32 temp;
        bytes32 next;
        
        temp = orders[tokenAddress][first_buy_order_id[tokenAddress]].id;

        while(temp != 0)
        {
            next = getNextOrder(tokenAddress, temp);
            cancelOrder(tokenAddress, temp);
            temp = next;
        }

        temp = orders[tokenAddress][first_sell_order_id[tokenAddress]].id;

        while(temp != 0)
        {
            next = getNextOrder(tokenAddress, temp);
            cancelOrder(tokenAddress, temp);
            temp = next;
        }

    }

    function flushAndClose(address tokenAddress) private onlyOwner {

        flush(tokenAddress);

        setIsExchangeOpen(false);

    }


    // ------------------------------------------------------------------------

    // Insert a buy order in the order queue

    // Market orders are placed first sorted by seniority

    // Limit orders are placed with highest bid first and then sorted

    // by seniority

    // ------------------------------------------------------------------------

    function insertBuyOrder(address _token, bytes32 _order_id) internal {

        bytes32 position;

        //In case no other buy order exists
        if(first_buy_order_id[_token] == 0) {
            first_buy_order_id[_token] = _order_id;
            return;
        }

        //loop through the buy order book and insert new buy orders
        position = first_buy_order_id[_token];

        do
        {
            //insert market orders before limit order (first market order)
            if(orders[_token][_order_id].limit == 0 &&
            orders[_token][position].limit != 0 &&
            (orders[_token][getPreviousOrder(_token, position)].id == 0 ||
            orders[_token][getPreviousOrder(_token, position)].limit == 0)) {

                if(orders[_token][getPreviousOrder(_token, position)].id == 0)
                    first_buy_order_id[_token] = _order_id;

                orders[_token][_order_id].previous_order = getPreviousOrder(_token, position);
                orders[_token][_order_id].next_order = position;
                orders[_token][getPreviousOrder(_token, position)].next_order = _order_id;
                orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert market order after the last market order
            if(orders[_token][_order_id].limit == 0 &&
            orders[_token][position].limit == 0 &&
            (orders[_token][getNextOrder(_token, position)].id == 0 ||
            orders[_token][getNextOrder(_token, position)].limit != 0)) {

                orders[_token][_order_id].previous_order = position;
                orders[_token][_order_id].next_order = orders[_token][position].next_order;
                orders[_token][getNextOrder(_token, position)].previous_order = _order_id;
                orders[_token][position].next_order = _order_id;

                return;
            }

            //insert limit order for new highest bid
            if(orders[_token][_order_id].limit != 0 &&
            orders[_token][position].limit != 0 &&
            orders[_token][_order_id].limit > orders[_token][position].limit &&
                (orders[_token][getPreviousOrder(_token, position)].id == 0 ||
                orders[_token][getPreviousOrder(_token, position)].limit == 0)) {

                if(orders[_token][getPreviousOrder(_token, position)].id == 0)
                    first_buy_order_id[_token] = _order_id;

                orders[_token][_order_id].previous_order = orders[_token][getPreviousOrder(_token, position)].id;
                orders[_token][_order_id].next_order = position;
                orders[_token][getPreviousOrder(_token, position)].next_order = _order_id;
                orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert limit order, case where the order is among existing limit buy orders
            //or first limit order after market order(s)
            if((orders[_token][_order_id].limit != 0 &&
            orders[_token][position].limit != 0 &&
            orders[_token][_order_id].limit <= orders[_token][position].limit &&
            orders[_token][_order_id].block_nr >= orders[_token][position].block_nr && //to be tested for block order
            (orders[_token][getNextOrder(_token, position)].id == 0 ||
            orders[_token][_order_id].limit > orders[_token][getNextOrder(_token, position)].limit)) ||
            orders[_token][_order_id].limit != 0 &&
            orders[_token][position].limit == 0 &&
            orders[_token][getNextOrder(_token, position)].id == 0) {

                orders[_token][_order_id].previous_order = position;
                orders[_token][_order_id].next_order = getNextOrder(_token, position);
                orders[_token][getNextOrder(_token, position)].previous_order = _order_id;
                orders[_token][position].next_order = _order_id;

                return;
            }

            position = getNextOrder(_token, position);

        } while(position != 0);

    }


    // ------------------------------------------------------------------------

    // Insert a sell order in the order queue

    // Market orders are placed first sorted by seniority

    // Limit orders are placed with lowest ask first and then sorted

    // by seniority

    // ------------------------------------------------------------------------

    function insertSellOrder(address _token, bytes32 _order_id) internal {
        bytes32 position;

        if(first_sell_order_id[_token] == 0) {

            first_sell_order_id[_token] = _order_id;
            return;

        }

        position = first_sell_order_id[_token];

        do
        {
            //insert orders, market orders with limit 0 first_sell_order_id
            //then limit order by ascending order. Orders of equal limit
            //sorted ascending by block nr
            if(orders[_token][_order_id].limit < orders[_token][position].limit) {

                if(orders[_token][position].previous_order == 0) {
                    first_sell_order_id[_token] = _order_id;
                }

                orders[_token][_order_id].previous_order = getPreviousOrder(_token, position);
                orders[_token][_order_id].next_order = position;
                orders[_token][getPreviousOrder(_token, position)].next_order = _order_id;
                orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert limit order, case where the order is among existing limit buy orders
            if(orders[_token][_order_id].limit >= orders[_token][position].limit &&
            (orders[_token][_order_id].limit < orders[_token][getNextOrder(_token, position)].limit ||
            orders[_token][getNextOrder(_token, position)].id == 0) &&
            orders[_token][_order_id].block_nr >= orders[_token][position].block_nr) {

                orders[_token][_order_id].previous_order = position;
                orders[_token][_order_id].next_order = getNextOrder(_token, position);
                orders[_token][getNextOrder(_token, position)].previous_order = _order_id;
                orders[_token][position].next_order = _order_id;

                return;
            }

            position = getNextOrder(_token, position);

        } while(position != 0);
    }


    // ------------------------------------------------------------------------

    // Withdraw Eth from the traders balance

    // ------------------------------------------------------------------------

    function withdrawEth(address _sender) public {
        
        require(msg.sender == _sender);

        uint balance = eth_balance[msg.sender];
        eth_balance[msg.sender] = 0;
        msg.sender.transfer(balance);

    }


    // ------------------------------------------------------------------------

    // Withdraw Tokens from the traders balance

    // ------------------------------------------------------------------------

    function withdrawToken(address _token, address _sender) public {

        require(msg.sender == _sender);

        uint balance = token_balance[_token][msg.sender];
        token_balance[_token][_sender] = 0;
        ERC20Interface(_token).transfer(_sender, balance);
        
    }


    // ------------------------------------------------------------------------

    // Allows the owner to withdraw Eth from the fees pool

    // ------------------------------------------------------------------------

    function withdrawFees() public onlyOwner  {
        uint fee_amount = fees_pool;
        fees_pool = 0;
        owner.transfer(fee_amount);
    }


    // ------------------------------------------------------------------------

    // Open or close the exchange

    // ------------------------------------------------------------------------

    function setIsExchangeOpen(bool status) public onlyOwner {
        is_exchange_open = status;
    }


    // ------------------------------------------------------------------------

    // Called to place sell orders, so that the tokens

    // can be transferred to the exchange

    // ------------------------------------------------------------------------

    function receiveApproval(address _from, uint _token, address _tokenContract, bytes _data) public {
        
        if(!ERC20Interface(_tokenContract).transferFrom(_from, this, _token)) {
            revert();
        }
        
        place_sell_order(_from, _tokenContract, _token, bytesToUint(_data));

    }


    // ------------------------------------------------------------------------

    // Closes the exchange for good,  

    // to call flush and close in final version and repay everyone

    // ------------------------------------------------------------------------

    function close() public onlyOwner {

        selfdestruct(owner);

    }


    // ------------------------------------------------------------------------
    
    // Used to convert the data receives as argument in receiveApproval.
    
    // Used to pass the limit in the sell order, e.g. 0x10 = limit of 1 wei
    
    // ------------------------------------------------------------------------

    function bytesToUint(bytes b) public pure returns (uint){

        uint number;

        for(uint i=0;i<b.length;i++){
            
            number = number + uint(b[b.length-1-i])*(10**i);
            
        }

        return number;
    }
    
    
    // ------------------------------------------------------------------------
    
    // Only during test phase or to be updated for not allowing transferToken
    
    // of client's token
    
    // ------------------------------------------------------------------------
    
    function transferToken(address _tokenAddress, address _to, uint _token) private onlyOwner {
        
        ERC20Interface(_tokenAddress).transferFrom(this, _to, _token);
        
    }

    // ------------------------------------------------------------------------
    
    // Management of the tokens listed on the exchange
    
    // ------------------------------------------------------------------------

    function addToken(address tokenAddress) public onlyOwner {
        
        if(is_token_listed[tokenAddress] == false) {
            token_list_array.push(tokenAddress);
            listed_tokens[tokenAddress] = ERC20Interface(tokenAddress).symbol();
            is_token_listed[tokenAddress] = true;
        } else {
            listed_tokens[tokenAddress] = ERC20Interface(tokenAddress).symbol();
        }

    }
    
    
    // ------------------------------------------------------------------------
    
    // Emit function places separately due to stack overflow
    
    // ------------------------------------------------------------------------

    function emitOrder(address token, bytes32 order_id) internal {
        emit Placed(
            order_id, 
            orders[token][order_id].from, token,
            orders[token][order_id].order_type,
            orders[token][order_id].block_nr,
            orders[token][order_id].eth_sent,
            orders[token][order_id].eth_left,
            orders[token][order_id].token_amount,
            orders[token][order_id].token_left,
            orders[token][order_id].limit,
            orders[token][order_id].previous_order,
            orders[token][order_id].next_order);
    }

    // ------------------------------------------------------------------------

    // Getters and setters for web3 interface

    // ------------------------------------------------------------------------


    // Tokens
    function getTokenListLength() public view returns(uint) {
        return token_list_array.length;
    }

    function getTokenAddress(uint pos) public view returns(address) {
        return token_list_array[pos];
    }

    function getTokenSymbol(address tokenAddress) public view returns(string) {
        return listed_tokens[tokenAddress];
    }


    //Info
    function getLastPrice(address tokenAddress) public view returns(uint) {
        return trades[tokenAddress][bytes32(trade_list[tokenAddress][getExecutionsLength(tokenAddress)-1])].price;
    }

    function getLastVolume(address tokenAddress) public view returns(uint) {
        return trades[tokenAddress][bytes32(trade_list[tokenAddress][getExecutionsLength(tokenAddress)-1])].price * 
            trades[tokenAddress][bytes32(trade_list[tokenAddress][getExecutionsLength(tokenAddress)-1])].exec_amount;
    }


    // Executions
    function getExecutionsLength(address _token) public view returns(uint) {
        return trade_list[_token].length;
    }

    function getExecutionId(address _token, uint _pos) public view returns(uint) {
        return trade_list[_token][_pos];
    }

    function getExecutionBlockNr(address _token, bytes32 _execId) public view returns(uint) {
        return trades[_token][_execId].block_nr;
    }

    function getExecutionType(address _token, bytes32 _execId) public view returns(bool) {
        return trades[_token][_execId].order_type;
    }

    function getExecutionBuyOrderId(address _token, bytes32 _execId) public view returns(bytes32) {
        return trades[_token][_execId].buy_order_id;
    }

    function getExecutionSellOrderId(address _token, bytes32 _execId) public view returns(bytes32) {
        return trades[_token][_execId].sell_order_id;
    }

    function getExecutionTokenAmount(address _token, bytes32 _execId) public view returns(uint) {
        return trades[_token][_execId].exec_amount;
    }

    function getExecutionPrice(address _token, bytes32 _execId) public view returns(uint) {
        return trades[_token][_execId].price;
    }

    function getExecutionTimestamp(address _token, bytes32 _execId) public view returns(uint) {
        return trades[_token][_execId].timestamp;
    }

    // Orders
    function getOrderListLength(address _token) public view returns (uint) {
        return order_list[_token].length;
    }
    
    function getOrderId(address _token, uint _pos) public view returns(uint){
        return order_list[_token][_pos];
    }

    function getOrderBlockNr(address _token, bytes32 _orderId) public view returns (uint) {
        return orders[_token][_orderId].block_nr;
    }

    function getOrderFrom(address _token, bytes32 _orderId) public view returns (address) {
        return orders[_token][_orderId].from;
    }

    function getOrderType(address _token, bytes32 _orderId) public view returns (bool) {
        return orders[_token][_orderId].order_type;
    }

    function getOrderEthSent(address _token, bytes32 _orderId) public view returns (uint) {
        return orders[_token][_orderId].eth_sent;
    }

    function getOrderEthLeft(address _token, bytes32 _orderId) public view returns (uint) {
        return orders[_token][_orderId].eth_left;
    }

    function getOrderTokenAmount(address _token, bytes32 _orderId) public view returns (uint) {
        return orders[_token][_orderId].token_amount;
    }

    function getOrderTokenLeft(address _token, bytes32 _orderId) public view returns (uint) {
        return orders[_token][_orderId].token_left;
    }

    function getOrderEthPriceLimit(address _token, bytes32 _orderId) public view returns (uint) {
        return orders[_token][_orderId].limit;
    }

    function getPreviousOrder(address _token, bytes32 _orderId) public view returns (bytes32) {
        return orders[_token][_orderId].previous_order;
    }

    function getNextOrder(address _token, bytes32 _orderId) public view returns (bytes32) {
        return orders[_token][_orderId].next_order;
    }

    function isOrderCancelled(address _token, bytes32 _orderId) public view returns (bool) {
        return orders[_token][_orderId].cancelled;
    }

    function isOrderExecuted(address _token, bytes32 _orderId) public view returns (bool) {
        return orders[_token][_orderId].executed;
    }


    // Various utils
    function max(uint a, uint b) internal pure returns (uint) {
        if(a >= b)
            return a;
        else
            return b;
    }

    function min(uint a, uint b) internal pure returns (uint) {
        if(a <= b)
            return a;
        else
            return b;
    }

}
    