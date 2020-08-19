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

    function totalSupply() public constant returns (uint);

    function balanceOf(address tokenOwner) public constant returns (uint balance);

    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);

    function transfer(address to, uint tokens) public returns (bool success);

    function approve(address spender, uint tokens) public returns (bool success);

    function transferFrom(address from, address to, uint tokens) public returns (bool success);


    event Transfer(address indexed from, address indexed to, uint tokens);

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}


contract _0xChange is Ownable {


    //allows to close the exchange
    bool is_exchange_open;

    //last price paid on the exchange
    mapping(address => uint[]) public last_price;
    mapping(address => uint[]) public volume;

    //First order of the queue for each token
    mapping(address => bytes32) public first_buy_order_id;
    mapping(address => bytes32) public first_sell_order_id;

    //mapping of executed orders by trx id
    mapping(address => mapping(bytes32 => order)) public buy_orders;
    mapping(address => mapping(bytes32 => order)) public sell_orders;

    //mapping of all orders in uint format, can be converted
    //back toHex to access other data from the order book
    mapping(address => mapping(address => uint[])) public my_buy_orders;
    mapping(address => mapping(address => uint[])) public my_sell_orders;

    //Executions records
    //(i) mapping token => order_id => (uint) execution_id
    //(ii) mapping token => execution_id => execution
    //(iii) mapping token => (uint) execution_id
    mapping(address => mapping(bytes32 => uint[])) public my_executions;
    mapping(address => mapping(bytes32 => execution)) public executions;
    mapping(address => uint[]) public execution_list;

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
    
    event Executed(address token, bytes32 execution_id);

    //Default Constructor
    constructor() public payable {
        is_exchange_open = true;
    }

    //Order struct
    struct order{
        bytes32 id;
        address token_address;
        uint block_nr;
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


    //Order struct
    struct execution{
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

    // Place an order in the buy_orders mapping

    // The queue is organized with market order first and then 

    // Limit order sorted from highest to lowest bid

    // ------------------------------------------------------------------------

    function place_buy_order(address _token, uint _amount, uint _limit) public payable returns (bytes32 order_nr) {
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

        buy_orders[_token][order_id].id = order_id;
        buy_orders[_token][order_id].token_address = _token;
        buy_orders[_token][order_id].block_nr = block.number;
        buy_orders[_token][order_id].from = msg.sender;
        buy_orders[_token][order_id].eth_sent = msg.value;
        buy_orders[_token][order_id].eth_left = msg.value;
        buy_orders[_token][order_id].token_amount = _amount;
        buy_orders[_token][order_id].token_left = _amount;
        buy_orders[_token][order_id].limit = _limit;
        buy_orders[_token][order_id].executed = false;
        buy_orders[_token][order_id].cancelled = false;
        buy_orders[_token][order_id].previous_order = bytes32(0);
        buy_orders[_token][order_id].next_order = bytes32(0);

        my_buy_orders[_token][msg.sender].push(uint(order_id));

        insertBuyOrder(_token, order_id);

        matching(_token, true);

        return order_id;
    }


    // ------------------------------------------------------------------------

    // Place an order in the sell_orders mapping

    // Called internally from ReceiveApproval

    // The queue is organized with market order first and then 

    // Limit order sorted from high lowest to highes ask

    // ------------------------------------------------------------------------

    function place_sell_order(address _seller, address _token, uint _amount, uint _limit) internal returns (bytes32 order_nr) {
        require(is_exchange_open);

        bytes32 order_id = keccak256(
            abi.encodePacked(
                block.number,
                _token,
                msg.sender,
                _amount,
                _limit));

        sell_orders[_token][order_id].id = order_id;
        sell_orders[_token][order_id].token_address = _token;
        sell_orders[_token][order_id]. block_nr = block.number;
        sell_orders[_token][order_id].from = _seller;
        sell_orders[_token][order_id].eth_sent = msg.value;
        sell_orders[_token][order_id].eth_left = msg.value;
        sell_orders[_token][order_id].token_amount = _amount;
        sell_orders[_token][order_id].token_left = _amount;
        sell_orders[_token][order_id].limit = _limit;
        sell_orders[_token][order_id].executed = false;
        sell_orders[_token][order_id].cancelled = false;
        sell_orders[_token][order_id].previous_order = bytes32(0);
        sell_orders[_token][order_id].next_order = bytes32(0);

        my_sell_orders[_token][_seller].push(uint(order_id));

        insertSellOrder(_token, order_id);

        matching(_token, false);

        return order_id;
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
            price = transactionPrice(_token);
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

            executions[_token][exec_id].id = exec_id;
            executions[_token][exec_id].token_address = _token;
            executions[_token][exec_id].block_nr = block.number;
            executions[_token][exec_id].timestamp = block.timestamp;
            executions[_token][exec_id].order_type = _type;
            executions[_token][exec_id].buy_order_id = first_buy_order_id[_token];
            executions[_token][exec_id].sell_order_id = first_sell_order_id[_token];
            executions[_token][exec_id].exec_amount = amount;
            executions[_token][exec_id].price = price;    

            last_price[_token].push(price);     

            my_executions[_token][first_buy_order_id[_token]].push(uint(exec_id));
            my_executions[_token][first_sell_order_id[_token]].push(uint(exec_id));

            execution_list[_token].push(uint(exec_id));

            settlement(_token, exec_id);

        }
    }


    // ------------------------------------------------------------------------

    // Compare the first orders of the bid and ask and define if

    // a matching is possible

    // ------------------------------------------------------------------------

    function matchingPossible(address _token) internal view returns (bool) {
        return (buy_orders[_token][first_buy_order_id[_token]].limit >= sell_orders[_token][first_sell_order_id[_token]].limit ||
        (buy_orders[_token][first_buy_order_id[_token]].limit == 0 || sell_orders[_token][first_sell_order_id[_token]].limit == 0)) &&
        (first_buy_order_id[_token] != 0 && first_sell_order_id[_token] != 0);
    }


    // ------------------------------------------------------------------------

    // Return the transaction price:

    // 1) Market order vs Market order: lower of last price or best offer

    // 2) Market order vs Limit Order: limit order

    // ------------------------------------------------------------------------

    function transactionPrice(address _token) internal view returns (uint) {

        if(buy_orders[_token][first_buy_order_id[_token]].limit == 0
            && sell_orders[_token][first_sell_order_id[_token]].limit == 0) {

            return getBestPrice(_token);

        } else if(buy_orders[_token][first_buy_order_id[_token]].limit == 0
            && sell_orders[_token][first_sell_order_id[_token]].limit != 0) {

            return sell_orders[_token][first_sell_order_id[_token]].limit;

        } else if(buy_orders[_token][first_buy_order_id[_token]].limit != 0
            && sell_orders[_token][first_sell_order_id[_token]].limit == 0) {

            return buy_orders[_token][first_buy_order_id[_token]].limit;

        } else if (buy_orders[_token][first_buy_order_id[_token]].limit != 0
            && sell_orders[_token][first_sell_order_id[_token]].limit != 0) {
            //Update needed        
            return sell_orders[_token][first_sell_order_id[_token]].limit;

        }

    }


    // ------------------------------------------------------------------------

    // Return transaction amount as the lowest of the bid amount, 

    // the offer amount and the maximal amount that the buyers can aquire as

    // the ether left on the order divided by the transaction price

    // ------------------------------------------------------------------------

    function transactionAmount(address _token, uint price) internal view returns(uint) {

        return min(buy_orders[_token][first_buy_order_id[_token]].token_left, min(
            buy_orders[_token][first_buy_order_id[_token]].eth_left * 
            (10**uint(ERC20Interface(_token).decimals())) / price,
            sell_orders[_token][first_sell_order_id[_token]].token_left));

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

        uint trx_volume = executions[_token][_exec_id].exec_amount *
            executions[_token][_exec_id].price / 
            (10**uint(ERC20Interface(_token).decimals()));
        volume[_token].push(trx_volume);
        uint fee_payment;
        uint payment;

        //update orders
        buy_orders[_token][first_buy_order_id[_token]].token_left -= executions[_token][_exec_id].exec_amount;
        sell_orders[_token][first_sell_order_id[_token]].token_left -= executions[_token][_exec_id].exec_amount;
        buy_orders[_token][first_buy_order_id[_token]].eth_left -= trx_volume;

        //update execution
        my_executions[_token][first_buy_order_id[_token]].push(uint(_exec_id));
        my_executions[_token][first_sell_order_id[_token]].push(uint(_exec_id));


        //Fee processing
        fee_payment = trx_volume * fees / 10000;
        payment = trx_volume - fee_payment;

        token_balance[_token][getBuyOrderFrom(_token, executions[_token][_exec_id].buy_order_id)] += executions[_token][_exec_id].exec_amount;
        eth_balance[getSellOrderFrom(_token, executions[_token][_exec_id].sell_order_id)] += payment;
        fees_pool += fee_payment;

        emit Executed(_token, _exec_id);

        //Consider an order as executed if the token amount left is zero
        //or if the eth amount left is smaller than 10000000000 wei (0.00000001 ETH)
        if(buy_orders[_token][first_buy_order_id[_token]].token_left == 0 ||
            buy_orders[_token][first_buy_order_id[_token]].eth_left < 10000000000) {

            buy_orders[_token][first_buy_order_id[_token]].executed = true;

            eth_balance[getBuyOrderFrom(_token, executions[_token][_exec_id].buy_order_id)] += buy_orders[_token][first_buy_order_id[_token]].eth_left;
            buy_orders[_token][first_buy_order_id[_token]].eth_left = 0;

            first_buy_order_id[_token] = buy_orders[_token][first_buy_order_id[_token]].next_order;

            buy_orders[_token][first_buy_order_id[_token]].previous_order = bytes32(0);
            buy_orders[_token][executions[_token][_exec_id].buy_order_id].next_order = bytes32(0);
            
        }


        if(sell_orders[_token][first_sell_order_id[_token]].token_left == 0) {

            sell_orders[_token][first_sell_order_id[_token]].executed = true;

            first_sell_order_id[_token] = sell_orders[_token][first_sell_order_id[_token]].next_order;

            sell_orders[_token][first_sell_order_id[_token]].previous_order = bytes32(0);
            sell_orders[_token][executions[_token][_exec_id].sell_order_id].next_order = bytes32(0);

        }

    }


    // ------------------------------------------------------------------------

    // Calculate best price for market orders by returning

    // the lower of the the last price paid or the lowest ask    

    // ------------------------------------------------------------------------

    function getBestPrice(address _token) public view returns (uint price) {
        //lowest of last paid price or lowest limit sell order
        //used to execute market orders
        bytes32 position = first_sell_order_id[_token];
        uint best_price = last_price[_token][last_price[_token].length-1];

        while(sell_orders[_token][position].id != 0)
        {
            if(sell_orders[_token][position].limit != 0 &&
            sell_orders[_token][position].limit < best_price) {

                best_price = sell_orders[_token][position].limit;

            }

            position = sell_orders[_token][getNextSellOrder(_token, position)].id;
        }

        return best_price;

    }


    // ------------------------------------------------------------------------

    // Cancel an order, remove it from the chain of orders and

    // increase eth balance of the trader by the eth left   

    // ------------------------------------------------------------------------

    function cancelBuyOrder(address _token, bytes32 orderId) public {

        require(msg.sender == buy_orders[_token][orderId].from);
        require(buy_orders[_token][orderId].cancelled == false);
        require(buy_orders[_token][orderId].executed == false);

        order memory _order = buy_orders[_token][orderId];

        if(first_buy_order_id[_token] == orderId)
            first_buy_order_id[_token] = _order.next_order;

        buy_orders[_token][_order.previous_order].next_order = _order.next_order;
        buy_orders[_token][_order.next_order].previous_order = _order.previous_order;

        _order.next_order = bytes32(0);
        _order.previous_order = bytes32(0);

        _order.cancelled = true;

        eth_balance[_order.from] += _order.eth_left;

        _order.eth_left = 0;
        
        buy_orders[_token][orderId] = _order;

    }


    // ------------------------------------------------------------------------

    // Cancel an order, remove it from the chain of orders and

    // increase token balance of the trader by the token left  

    // ------------------------------------------------------------------------

    function cancelSellOrder(address _token, bytes32 orderId) public {

        require(msg.sender == sell_orders[_token][orderId].from);
        require(sell_orders[_token][orderId].cancelled == false);
        require(sell_orders[_token][orderId].executed == false);
        
        order memory _order = sell_orders[_token][orderId];
        
        if(first_sell_order_id[_token] == orderId)
            first_sell_order_id[_token] = _order.next_order;

        sell_orders[_token][_order.previous_order].next_order = _order.next_order;
        sell_orders[_token][_order.next_order].previous_order = _order.previous_order;

        _order.next_order = bytes32(0);
        _order.previous_order = bytes32(0);

        _order.cancelled = true;
    
        token_balance[_token][_order.from] += _order.token_amount;
        
        _order.token_amount = 0;

        sell_orders[_token][orderId] = _order;
    }

    function flush(address tokenAddress) private onlyOwner {

        bytes32 temp;
        bytes32 next;
        
        temp = buy_orders[tokenAddress][first_buy_order_id[tokenAddress]].id;

        while(temp != 0)
        {
            next = getNextBuyOrder(tokenAddress, temp);
            cancelBuyOrder(tokenAddress, temp);
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
            if(buy_orders[_token][_order_id].limit == 0 &&
            buy_orders[_token][position].limit != 0 &&
            (buy_orders[_token][getPreviousBuyOrder(_token, position)].id == 0 ||
            buy_orders[_token][getPreviousBuyOrder(_token, position)].limit == 0)) {

                if(buy_orders[_token][getPreviousBuyOrder(_token, position)].id == 0)
                    first_buy_order_id[_token] = _order_id;

                buy_orders[_token][_order_id].previous_order = getPreviousBuyOrder(_token, position);
                buy_orders[_token][_order_id].next_order = position;
                buy_orders[_token][getPreviousBuyOrder(_token, position)].next_order = _order_id;
                buy_orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert market order after the last market order
            if(buy_orders[_token][_order_id].limit == 0 &&
            buy_orders[_token][position].limit == 0 &&
            (buy_orders[_token][getNextBuyOrder(_token, position)].id == 0 ||
            buy_orders[_token][getNextBuyOrder(_token, position)].limit != 0)) {

                buy_orders[_token][_order_id].previous_order = position;
                buy_orders[_token][_order_id].next_order = buy_orders[_token][position].next_order;
                buy_orders[_token][getNextBuyOrder(_token, position)].previous_order = _order_id;
                buy_orders[_token][position].next_order = _order_id;

                return;
            }

            //insert limit order for new highest bid
            if(buy_orders[_token][_order_id].limit != 0 &&
            buy_orders[_token][position].limit != 0 &&
            buy_orders[_token][_order_id].limit > buy_orders[_token][position].limit &&
                (buy_orders[_token][getPreviousBuyOrder(_token, position)].id == 0 ||
                buy_orders[_token][getPreviousBuyOrder(_token, position)].limit == 0)) {

                if(buy_orders[_token][getPreviousBuyOrder(_token, position)].id == 0)
                    first_buy_order_id[_token] = _order_id;

                buy_orders[_token][_order_id].previous_order = buy_orders[_token][getPreviousBuyOrder(_token, position)].id;
                buy_orders[_token][_order_id].next_order = position;
                buy_orders[_token][getPreviousBuyOrder(_token, position)].next_order = _order_id;
                buy_orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert limit order, case where the order is among existing limit buy orders
            //or first limit order after market order(s)
            if((buy_orders[_token][_order_id].limit != 0 &&
            buy_orders[_token][position].limit != 0 &&
            buy_orders[_token][_order_id].limit <= buy_orders[_token][position].limit &&
            buy_orders[_token][_order_id].block_nr > buy_orders[_token][position].block_nr &&
            (buy_orders[_token][getNextBuyOrder(_token, position)].id == 0 ||
            buy_orders[_token][_order_id].limit > buy_orders[_token][getNextBuyOrder(_token, position)].limit)) ||
            buy_orders[_token][_order_id].limit != 0 &&
            buy_orders[_token][position].limit == 0 &&
            buy_orders[_token][getNextBuyOrder(_token, position)].id == 0) {

                buy_orders[_token][_order_id].previous_order = position;
                buy_orders[_token][_order_id].next_order = getNextBuyOrder(_token, position);
                buy_orders[_token][getNextBuyOrder(_token, position)].previous_order = _order_id;
                buy_orders[_token][position].next_order = _order_id;

                return;
            }

            position = getNextBuyOrder(_token, position);

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
            if(sell_orders[_token][_order_id].limit < sell_orders[_token][position].limit) {

                if(sell_orders[_token][position].previous_order == 0) {
                    first_sell_order_id[_token] = _order_id;
                }

                sell_orders[_token][_order_id].previous_order = getPreviousSellOrder(_token, position);
                sell_orders[_token][_order_id].next_order = position;
                sell_orders[_token][getPreviousSellOrder(_token, position)].next_order = _order_id;
                sell_orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert limit order, case where the order is among existing limit buy orders
            if(sell_orders[_token][_order_id].limit >= sell_orders[_token][position].limit &&
            (sell_orders[_token][_order_id].limit < sell_orders[_token][getNextSellOrder(_token, position)].limit ||
            sell_orders[_token][getNextSellOrder(_token, position)].id == 0) &&
            sell_orders[_token][_order_id].block_nr > sell_orders[_token][position].block_nr) {

                sell_orders[_token][_order_id].previous_order = position;
                sell_orders[_token][_order_id].next_order = getNextSellOrder(_token, position);
                sell_orders[_token][getNextSellOrder(_token, position)].previous_order = _order_id;
                sell_orders[_token][position].next_order = _order_id;

                return;
            }

            position = getNextSellOrder(_token, position);

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

    // Getters and setters for web3 interface

    // ------------------------------------------------------------------------


    // Tokens
    function getTokenListLength() constant public returns(uint) {
        return token_list_array.length;
    }

    function getTokenAddress(uint pos) constant public returns(address) {
        return token_list_array[pos];
    }

    function getTokenSymbol(address tokenAddress) constant public returns(string) {
        return listed_tokens[tokenAddress];
    }


    //Info
    function getPriceLength(address tokenAddress) constant public returns(uint) {
        return last_price[tokenAddress].length;
    }

    function getLastPrice(address tokenAddress) constant public returns(uint) {
        return last_price[tokenAddress][last_price[tokenAddress].length-1];
    }

    function getPrice(address tokenAddress, uint pos) constant public returns(uint) {
        return last_price[tokenAddress][pos];
    }

    function getVolumeLength(address tokenAddress) constant public returns(uint) {
        return volume[tokenAddress].length;
    }

    function getLastVolume(address tokenAddress) constant public returns(uint) {
        return volume[tokenAddress][volume[tokenAddress].length-1];
    }

    function getVolume(address tokenAddress, uint pos) constant public returns(uint) {
        return volume[tokenAddress][pos];
    }


    // Executions
    function getOrderExecutionLength(address _token, bytes32 _orderId) constant public returns(uint) {
        return my_executions[_token][_orderId].length;
    }

    function getExecutionsLength(address _token) constant public returns(uint) {
        return execution_list[_token].length;
    }

    function getExecutionId(address _token, uint _pos) constant public returns(uint) {
        return execution_list[_token][_pos];
    }

    function getOrderExecutionId(address _token, bytes32 _orderId, uint _pos) constant public returns(uint) {
        return my_executions[_token][_orderId][_pos];
    }

    function getExecutionBlockNr(address _token, bytes32 _execId) constant public returns(uint) {
        return executions[_token][_execId].block_nr;
    }

    function getExecutionType(address _token, bytes32 _execId) constant public returns(bool) {
        return executions[_token][_execId].order_type;
    }

    function getExecutionBuyOrderId(address _token, bytes32 _execId) constant public returns(bytes32) {
        return executions[_token][_execId].buy_order_id;
    }

    function getExecutionSellOrderId(address _token, bytes32 _execId) constant public returns(bytes32) {
        return executions[_token][_execId].sell_order_id;
    }

    function getExecutionTokenAmount(address _token, bytes32 _execId) constant public returns(uint) {
        return executions[_token][_execId].exec_amount;
    }

    function getExecutionPrice(address _token, bytes32 _execId) constant public returns(uint) {
        return executions[_token][_execId].price;
    }

    function getExecutionTimestamp(address _token, bytes32 _execId) constant public returns(uint) {
        return executions[_token][_execId].timestamp;
    }

    // Orders
    function getBuyOrderBlockNr(address _token, bytes32 _orderId) constant public returns (uint) {
        return buy_orders[_token][_orderId].block_nr;
    }

    function getSellOrderBlockNr(address _token, bytes32 _orderId) constant public returns (uint) {
        return sell_orders[_token][_orderId].block_nr;
    }

    function getBuyOrderFrom(address _token, bytes32 _orderId) constant public returns (address) {
        return buy_orders[_token][_orderId].from;
    }

    function getSellOrderFrom(address _token, bytes32 _orderId) constant public returns (address) {
        return sell_orders[_token][_orderId].from;
    }

    function getBuyOrderEthSent(address _token, bytes32 _orderId) constant public returns (uint) {
        return buy_orders[_token][_orderId].eth_left;
    }

    function getBuyOrderEthLeft(address _token, bytes32 _orderId) constant public returns (uint) {
        return buy_orders[_token][_orderId].eth_left;
    }

    function getBuyOrderTokenAmount(address _token, bytes32 _orderId) constant public returns (uint) {
        return buy_orders[_token][_orderId].token_amount;
    }

    function getBuyOrderTokenLeft(address _token, bytes32 _orderId) constant public returns (uint) {
        return buy_orders[_token][_orderId].token_left;
    }

    function getSellOrderTokenAmount(address _token, bytes32 _orderId) constant public returns (uint) {
        return sell_orders[_token][_orderId].token_amount;
    }

    function getSellOrderTokenLeft(address _token, bytes32 _orderId) constant public returns (uint) {
        return sell_orders[_token][_orderId].token_left;
    }

    function getBuyOrderEthPriceLimit(address _token, bytes32 _orderId) constant public returns (uint) {
        return buy_orders[_token][_orderId].limit;
    }

    function getSellOrderEthPriceLimit(address _token, bytes32 _orderId) constant public returns (uint) {
        return sell_orders[_token][_orderId].limit;
    }

    function getPreviousBuyOrder(address _token, bytes32 _orderId) constant public returns (bytes32) {
        return buy_orders[_token][_orderId].previous_order;
    }

    function getPreviousSellOrder(address _token, bytes32 _orderId) constant public returns (bytes32) {
        return sell_orders[_token][_orderId].previous_order;
    }

    function getNextBuyOrder(address _token, bytes32 _orderId) constant public returns (bytes32) {
        return buy_orders[_token][_orderId].next_order;
    }

    function getNextSellOrder(address _token, bytes32 _orderId) constant public returns (bytes32) {
        return sell_orders[_token][_orderId].next_order;
    }

    function isBuyOrderCancelled(address _token, bytes32 _orderId) constant public returns (bool) {
        return buy_orders[_token][_orderId].cancelled;
    }

    function isSellOrderCancelled(address _token, bytes32 _orderId) constant public returns (bool) {
        return sell_orders[_token][_orderId].cancelled;
    }

    function isBuyOrderExecuted(address _token, bytes32 _orderId) constant public returns (bool) {
        return buy_orders[_token][_orderId].executed;
    }

    function isSellOrderExecuted(address _token, bytes32 _orderId) constant public returns (bool) {
        return sell_orders[_token][_orderId].executed;
    }

    function getMyBuyOrdersLength(address _token, address from) constant public returns (uint) {
        return my_buy_orders[_token][from].length;
    }

    function getMyBuyOrders(address _token, address from, uint position) constant public returns(uint) {
        return my_buy_orders[_token][from][position];
    }

    function getMySellOrdersLength(address _token, address from) constant public returns (uint) {
        return my_sell_orders[_token][from].length;
    }

    function getMySellOrders(address _token, address from, uint position) constant public returns(uint) {
        return my_sell_orders[_token][from][position];
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
    