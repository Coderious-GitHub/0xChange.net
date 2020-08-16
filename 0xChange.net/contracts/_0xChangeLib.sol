// SPDX-License-Identifier: Unlicense

pragma solidity ^0.7.0;

//Order struct
struct Order {
    bytes32 id;
    address token_address;
    uint256 block_nr;
    bool order_type;
    address from;
    uint256 eth_sent;
    uint256 eth_left;
    uint256 token_amount;
    uint256 token_left;
    uint256 limit;
    bool executed;
    bool cancelled;
    bytes32 previous_order;
    bytes32 next_order;
}

//Trade struct
struct Trade {
    bytes32 id;
    address token_address;
    uint256 block_nr;
    uint256 timestamp;
    bool order_type;
    bytes32 buy_order_id;
    bytes32 sell_order_id;
    uint256 exec_amount;
    uint256 price;
}

//Exchange Struct
struct Exchange {
    //First order of the queue
    mapping(address => bytes32) first_buy_order_id;
    mapping(address => bytes32) first_sell_order_id;
    //mapping of all orders by order_id in uint format
    //can be reconverted to the right format using web3.toHex
    mapping(address => mapping(bytes32 => Order)) orders;
    mapping(address => uint256[]) order_list;
    //Executions records
    //(i) mapping token => execution_id => execution
    //(ii) mapping token => (uint) execution_id
    mapping(address => mapping(bytes32 => Trade)) trades;
    mapping(address => uint256[]) trade_list;
    //mapping of address with current balance with the exchange
    mapping(address => uint256) eth_balance;
    mapping(address => mapping(address => uint256)) token_balance;
    //mapping of listed tokens
    mapping(address => string) listed_tokens;
    mapping(address => bool) is_token_listed;
    address[] token_list_array;
    bool is_exchange_open;
}

contract _0xChange {
    Exchange private exchange;
    
    constructor(){
        exchange.is_exchange_open = true;
    }
    
    
    function buy(address _token, uint _amount, uint _limit) public payable
    {
        _0xChangeLib.place_buy_order(exchange, _token, _amount, _limit);
    }
    
    function sell(address _seller, address _token, uint _amount, uint _limit) public
    {
        _0xChangeLib.place_sell_order(exchange, _seller, _token, _amount, _limit);
    }
    
    function takeEth(address _sender) public
    {
        _0xChangeLib.withdrawEth(exchange, _sender);
    }
    
    function takeCoin(address _token, address _sender) public
    {
        _0xChangeLib.withdrawToken(exchange, _token, _sender);
    }
    
    function cancel(address _token, bytes32 orderId) public
    {
        _0xChangeLib.cancelOrder(exchange, _token, orderId);
    }
    
    
    function receiveApproval(address _from, uint _token, address _tokenContract, bytes memory _data) public {
        
        if(!ERC20Interface(_tokenContract).transferFrom(_from, address(this), _token)) {
            revert();
        }
        
        _0xChangeLib.place_sell_order(exchange, _from, _tokenContract, _token, _0xChangeLib.toUint256(_data));

    }
    
    // ------------------------------------------------------------------------

    // Getters and setters for web3 interface

    // ------------------------------------------------------------------------


    // User
    function getEthBalance(address user) public view returns(uint256) {
        return exchange.eth_balance[user];
    }
    
    function getTokenBalance(address token, address user) public view returns(uint256) {
        return exchange.token_balance[token][user];
    }


    // Tokens
    function getTokenListLength() public view returns(uint) {
        return exchange.token_list_array.length;
    }

    function getTokenAddress(uint pos) public view returns(address) {
        return exchange.token_list_array[pos];
    }

    function getTokenSymbol(address tokenAddress) public view returns(string memory) {
        return exchange.listed_tokens[tokenAddress];
    }
    
    function addToken(address tokenAddress) public {
        
        if(exchange.is_token_listed[tokenAddress] == false) {
            exchange.token_list_array.push(tokenAddress);
            exchange.listed_tokens[tokenAddress] = ERC20Interface(tokenAddress).symbol();
            exchange.is_token_listed[tokenAddress] = true;
        } else {
            exchange.listed_tokens[tokenAddress] = ERC20Interface(tokenAddress).symbol();
        }

    }


    //Info
    function getLastPrice(address tokenAddress) public view returns(uint) {
        return exchange.trades[tokenAddress][bytes32(exchange.trade_list[tokenAddress][getExecutionsLength(tokenAddress)-1])].price;
    }

    
    function getFirstBuyOrder(address tokenAddress) public view returns(bytes32) {
        return exchange.first_buy_order_id[tokenAddress];
    }
    
    function getFirstSellOrder(address tokenAddress) public view returns(bytes32) {
        return exchange.first_sell_order_id[tokenAddress];
    }
    
    
    // Executions
    function getExecutionsLength(address _token) public view returns(uint) {
        return exchange.trade_list[_token].length;
    }


    // Order
    function getOrderFrom(address _token, bytes32 _orderId) public view returns (address) {
        return exchange.orders[_token][_orderId].from;
    }
    

}

library _0xChangeLib {

    //Event generated when an order is placed successfully
    event Placed(bytes32 order_id, address token_address, uint block_nr,
        bool order_type, address sender, uint eth_left, uint token_left, 
        uint limit, bool executed, bool cancelled, bytes32 previous_order,
        bytes32 next_order);

    event Updated(bytes32 order_id, address token, uint eth_left, 
        uint token_left, bool executed, bool cancelled, bytes32 previous_order, 
        bytes32 next_order);
    
    event Traded(bytes32 trade_id, address token_address, uint block_nr, 
        uint trade_timestamp, bool order_type, bytes32 buy_order_id, 
        bytes32 sell_order_id, uint trade_amount, uint trade_price);


    function place_buy_order(
        Exchange storage self,
        address _token,
        uint256 _amount,
        uint256 _limit
    ) public returns (bool) {
        require(
            (_amount * _limit) /
                (10**uint256(ERC20Interface(_token).decimals())) <=
                msg.value
        );
        require(msg.value > 0);
        require(self.is_exchange_open);

        bytes32 order_id = keccak256(
            abi.encodePacked(block.number, _token, msg.sender, _amount, _limit)
        );

        self.orders[_token][order_id].id = order_id;
        self.orders[_token][order_id].token_address = _token;
        self.orders[_token][order_id].block_nr = block.number;
        self.orders[_token][order_id].order_type = true;
        self.orders[_token][order_id].from = msg.sender;
        self.orders[_token][order_id].eth_sent = msg.value;
        self.orders[_token][order_id].eth_left = msg.value;
        self.orders[_token][order_id].token_amount = _amount;
        self.orders[_token][order_id].token_left = _amount;
        self.orders[_token][order_id].limit = _limit;
        self.orders[_token][order_id].executed = false;
        self.orders[_token][order_id].cancelled = false;
        self.orders[_token][order_id].previous_order = bytes32(0);
        self.orders[_token][order_id].next_order = bytes32(0);

        self.order_list[_token].push(uint256(order_id));

        insertBuyOrder(self, _token, order_id);
        emitOrder(self, _token, order_id);

        matching(self, _token, true);
    }

    function insertBuyOrder(
        Exchange storage self,
        address _token,
        bytes32 _order_id
    ) internal {
        bytes32 position;

        //In case no other buy order exists
        if (self.first_buy_order_id[_token] == 0) {
            self.first_buy_order_id[_token] = _order_id;
            return;
        }

        //loop through the buy order book and insert new buy orders
        position = self.first_buy_order_id[_token];

        do {
            //insert market orders before limit order (first market order)
            if (
                self.orders[_token][_order_id].limit == 0 &&
                self.orders[_token][position].limit != 0 &&
                (self.orders[_token][getPreviousOrder(self, _token, position)].id ==
                    0 ||
                    self.orders[_token][getPreviousOrder(self, _token, position)]
                        .limit ==
                    0)
            ) {
                if (
                    self.orders[_token][getPreviousOrder(self, _token, position)]
                        .id == 0
                ) self.first_buy_order_id[_token] = _order_id;

                self.orders[_token][_order_id]
                    .previous_order = getPreviousOrder(self, _token, position);
                self.orders[_token][_order_id].next_order = position;
                self.orders[_token][getPreviousOrder(self, _token, position)]
                    .next_order = _order_id;
                self.orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert market order after the last market order
            if (
                self.orders[_token][_order_id].limit == 0 &&
                self.orders[_token][position].limit == 0 &&
                (self.orders[_token][getNextOrder(self, _token, position)].id == 0 ||
                    self.orders[_token][getNextOrder(self, _token, position)].limit !=
                    0)
            ) {
                self.orders[_token][_order_id].previous_order = position;
                self.orders[_token][_order_id].next_order = self
                    .orders[_token][position]
                    .next_order;
                self.orders[_token][getNextOrder(self, _token, position)]
                    .previous_order = _order_id;
                self.orders[_token][position].next_order = _order_id;

                return;
            }

            //insert limit order for new highest bid
            if (
                self.orders[_token][_order_id].limit != 0 &&
                self.orders[_token][position].limit != 0 &&
                self.orders[_token][_order_id].limit >
                self.orders[_token][position].limit &&
                (self.orders[_token][getPreviousOrder(self, _token, position)].id ==
                    0 ||
                    self.orders[_token][getPreviousOrder(self, _token, position)]
                        .limit ==
                    0)
            ) {
                if (
                    self.orders[_token][getPreviousOrder(self, _token, position)]
                        .id == 0
                ) self.first_buy_order_id[_token] = _order_id;

                self.orders[_token][_order_id]
                    .previous_order = self.orders[_token][getPreviousOrder(
                    self, 
                    _token,
                    position
                )]
                    .id;
                self.orders[_token][_order_id].next_order = position;
                self.orders[_token][getPreviousOrder(self, _token, position)]
                    .next_order = _order_id;
                self.orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert limit order, case where the order is among existing limit buy orders
            //or first limit order after market order(s)
            if (
                (self.orders[_token][_order_id].limit != 0 &&
                    self.orders[_token][position].limit != 0 &&
                    self.orders[_token][_order_id].limit <=
                    self.orders[_token][position].limit &&
                    self.orders[_token][_order_id].block_nr >=
                    self.orders[_token][position].block_nr && //to be tested for block order
                    (self.orders[_token][getNextOrder(self, _token, position)].id ==
                        0 ||
                        self.orders[_token][_order_id].limit >
                        self.orders[_token][getNextOrder(self, _token, position)]
                            .limit)) ||
                (self.orders[_token][_order_id].limit != 0 &&
                    self.orders[_token][position].limit == 0 &&
                    self.orders[_token][getNextOrder(self, _token, position)].id == 0)
            ) {
                self.orders[_token][_order_id].previous_order = position;
                self.orders[_token][_order_id].next_order = getNextOrder(
                    self, 
                    _token,
                    position
                );
                self.orders[_token][getNextOrder(self, _token, position)]
                    .previous_order = _order_id;
                self.orders[_token][position].next_order = _order_id;

                return;
            }

            position = getNextOrder(self, _token, position);
        } while (position != 0);
    }

    function place_sell_order(Exchange storage self,
        address _seller,
        address _token,
        uint256 _amount,
        uint256 _limit
    ) internal returns (bool) {
        require(self.is_exchange_open);

        bytes32 order_id = keccak256(
            abi.encodePacked(block.number, _token, msg.sender, _amount, _limit)
        );

        self.orders[_token][order_id].id = order_id;
        self.orders[_token][order_id].token_address = _token;
        self.orders[_token][order_id].block_nr = block.number;
        self.orders[_token][order_id].order_type = false;
        self.orders[_token][order_id].from = _seller;
        self.orders[_token][order_id].eth_sent = 0;
        self.orders[_token][order_id].eth_left = 0;
        self.orders[_token][order_id].token_amount = _amount;
        self.orders[_token][order_id].token_left = _amount;
        self.orders[_token][order_id].limit = _limit;
        self.orders[_token][order_id].executed = false;
        self.orders[_token][order_id].cancelled = false;
        self.orders[_token][order_id].previous_order = bytes32(0);
        self.orders[_token][order_id].next_order = bytes32(0);

        self.order_list[_token].push(uint256(order_id));

        insertSellOrder(self, _token, order_id);
        emitOrder(self, _token, order_id);

        matching(self, _token, false);
    }

    function insertSellOrder(Exchange storage self, address _token, bytes32 _order_id) internal {
        bytes32 position;

        if (self.first_sell_order_id[_token] == 0) {
            self.first_sell_order_id[_token] = _order_id;
            return;
        }

        position = self.first_sell_order_id[_token];

        do {
            //insert orders, market orders with limit 0 first_sell_order_id
            //then limit order by ascending order. Orders of equal limit
            //sorted ascending by block nr
            if (
                self.orders[_token][_order_id].limit <
                self.orders[_token][position].limit
            ) {
                if (self.orders[_token][position].previous_order == 0) {
                    self.first_sell_order_id[_token] = _order_id;
                }

                self.orders[_token][_order_id].previous_order = getPreviousOrder(
                    self, 
                    _token,
                    position
                );
                self.orders[_token][_order_id].next_order = position;
                self.orders[_token][getPreviousOrder(self, _token, position)]
                    .next_order = _order_id;
                self.orders[_token][position].previous_order = _order_id;

                return;
            }

            //insert limit order, case where the order is among existing limit buy orders
            if (
                self.orders[_token][_order_id].limit >=
                self.orders[_token][position].limit &&
                (self.orders[_token][_order_id].limit <
                    self.orders[_token][getNextOrder(self, _token, position)].limit ||
                    self.orders[_token][getNextOrder(self, _token, position)].id ==
                    0) &&
                self.orders[_token][_order_id].block_nr >=
                self.orders[_token][position].block_nr
            ) {
                self.orders[_token][_order_id].previous_order = position;
                self.orders[_token][_order_id].next_order = getNextOrder(
                    self, 
                    _token,
                    position
                );
                self.orders[_token][getNextOrder(self, _token, position)]
                    .previous_order = _order_id;
                self.orders[_token][position].next_order = _order_id;

                return;
            }

            position = getNextOrder(self, _token, position);
        } while (position != 0);
    }
    
    // ------------------------------------------------------------------------

    // Withdraw Eth from the traders balance

    // ------------------------------------------------------------------------

    function withdrawEth(Exchange storage self, address _sender) public returns (bool) {
        
        require(msg.sender == _sender);

        uint balance = self.eth_balance[msg.sender];
        self.eth_balance[msg.sender] = 0;
        msg.sender.transfer(balance);
    }


    // ------------------------------------------------------------------------

    // Withdraw Tokens from the traders balance

    // ------------------------------------------------------------------------

    function withdrawToken(Exchange storage self, address _token, address _sender) public returns (bool){

        require(msg.sender == _sender);

        uint balance = self.token_balance[_token][msg.sender];
        self.token_balance[_token][_sender] = 0;
        ERC20Interface(_token).transfer(_sender, balance);
        
    }

    function matching(Exchange storage self, address _token, bool _type) public {
        bytes32 exec_id;
        uint256 price;
        uint256 amount;

        while (matchingPossible(self, _token)) {
            //set execution price for market vs market,
            //market vs limit order, limit vs market
            //and limit vs. limit type of order
            price = transactionPrice(self, _token, _type);
            amount = transactionAmount(self, _token, price);

            exec_id = keccak256(
                abi.encodePacked(
                    _token,
                    block.number,
                    _token,
                    self.first_buy_order_id[_token],
                    self.first_sell_order_id[_token],
                    price,
                    amount
                )
            );

            //Build the trade
            self.trades[_token][exec_id].id = exec_id;
            self.trades[_token][exec_id].token_address = _token;
            self.trades[_token][exec_id].block_nr = block.number;
            self.trades[_token][exec_id].timestamp = block.timestamp;
            self.trades[_token][exec_id].order_type = _type;
            self.trades[_token][exec_id]
                .buy_order_id = self.first_buy_order_id[_token];
            self.trades[_token][exec_id]
                .sell_order_id = self.first_sell_order_id[_token];
            self.trades[_token][exec_id].exec_amount = amount;
            self.trades[_token][exec_id].price = price;

            //Record the trades
            self.trade_list[_token].push(uint256(exec_id));

            //Settle payment and finalize the trade
            settlement(self, _token, exec_id);
        }
    }

    function settlement(Exchange storage self, address _token, bytes32 _exec_id) internal {
        uint256 trx_volume = (self.trades[_token][_exec_id].exec_amount *
            self.trades[_token][_exec_id].price) /
            (10**uint256(ERC20Interface(_token).decimals()));
        uint256 payment;

        //update orders
        self.orders[_token][self.first_buy_order_id[_token]]
            .token_left -= self.trades[_token][_exec_id].exec_amount;
        self.orders[_token][self.first_sell_order_id[_token]]
            .token_left -= self.trades[_token][_exec_id].exec_amount;
        self.orders[_token][self.first_buy_order_id[_token]]
            .eth_left -= trx_volume;

        payment = trx_volume;

        self.token_balance[_token][getOrderFrom(
            self,
            _token,
            self.trades[_token][_exec_id].buy_order_id
        )] += self.trades[_token][_exec_id].exec_amount;
        self.eth_balance[getOrderFrom(
            self,
            _token,
            self.trades[_token][_exec_id].sell_order_id
        )] += payment;

        //Consider an order as executed if the token amount left is zero
        //or if the eth amount left is smaller than 10000000000 wei (0.00000001 ETH)
        if (
            self.orders[_token][self.first_buy_order_id[_token]].token_left ==
            0 ||
            self.orders[_token][self.first_buy_order_id[_token]].eth_left <
            10000000000
        ) {
            self.orders[_token][self.first_buy_order_id[_token]].executed = true;

            self.eth_balance[getOrderFrom(
                self,
                _token,
                self.trades[_token][_exec_id].buy_order_id
            )] += self.orders[_token][self.first_buy_order_id[_token]].eth_left;
            self.orders[_token][self.first_buy_order_id[_token]].eth_left = 0;

            self.first_buy_order_id[_token] = self.orders[_token][self.first_buy_order_id[_token]]
                .next_order;

            self.orders[_token][self.first_buy_order_id[_token]]
                .previous_order = bytes32(0);
            self.orders[_token][self.trades[_token][_exec_id].buy_order_id]
                .next_order = bytes32(0);
        }

        if (
            self.orders[_token][self.first_sell_order_id[_token]].token_left == 0
        ) {
            self.orders[_token][self.first_sell_order_id[_token]].executed = true;

            self.first_sell_order_id[_token] = self.orders[_token][self.first_sell_order_id[_token]]
                .next_order;

            self.orders[_token][self.first_sell_order_id[_token]]
                .previous_order = bytes32(0);
            self.orders[_token][self.trades[_token][_exec_id].sell_order_id]
                .next_order = bytes32(0);
        }

        emit Traded(
            _exec_id,
            _token,
            self.trades[_token][_exec_id].block_nr,
            self.trades[_token][_exec_id].timestamp,
            self.trades[_token][_exec_id].order_type,
            self.trades[_token][_exec_id].buy_order_id,
            self.trades[_token][_exec_id].sell_order_id,
            self.trades[_token][_exec_id].exec_amount,
            self.trades[_token][_exec_id].price
        );
    }
    
    function cancelOrder(Exchange storage self, address _token, bytes32 orderId) public returns(bool) {

        require(msg.sender == self.orders[_token][orderId].from);
        require(self.orders[_token][orderId].cancelled == false);
        require(self.orders[_token][orderId].executed == false);

        Order memory _order = self.orders[_token][orderId];

        if(_order.order_type == true) {
            if(self.first_buy_order_id[_token] == orderId){
                self.first_buy_order_id[_token] = _order.next_order;
                self.orders[_token][_order.next_order].previous_order = _order.previous_order;
            } else {
                self.orders[_token][_order.previous_order].next_order = _order.next_order;
                self.orders[_token][_order.next_order].previous_order = _order.previous_order;
            }
        } else {
            if(self.first_sell_order_id[_token] == orderId){ 
                self.first_sell_order_id[_token] = _order.next_order;
                self.orders[_token][_order.next_order].previous_order = _order.previous_order;
            } else {
                self.orders[_token][_order.previous_order].next_order = _order.next_order;
                self.orders[_token][_order.next_order].previous_order = _order.previous_order;
            }
        }

        _order.previous_order = bytes32(0);
        _order.next_order = bytes32(0);

        _order.cancelled = true;

        self.eth_balance[_order.from] += _order.eth_left;

        _order.eth_left = 0;
        
        self.orders[_token][orderId] = _order;

    }
    

    function matchingPossible(Exchange storage self, address _token) internal view returns (bool) {
        return
            (self.orders[_token][self.first_buy_order_id[_token]].limit >=
                self.orders[_token][self.first_sell_order_id[_token]].limit ||
                (self.orders[_token][self.first_buy_order_id[_token]].limit ==
                    0 ||
                    self.orders[_token][self.first_sell_order_id[_token]].limit ==
                    0)) &&
            (self.first_buy_order_id[_token] != 0 &&
                self.first_sell_order_id[_token] != 0);
    }

    function transactionAmount(Exchange storage self, address _token, uint256 price)
        internal
        view
        returns (uint256)
    {
        return
            min(
                self.orders[_token][self.first_buy_order_id[_token]].token_left,
                min(
                    (self.orders[_token][self.first_buy_order_id[_token]]
                        .eth_left *
                        (10**uint256(ERC20Interface(_token).decimals()))) /
                        price,
                    self.orders[_token][self.first_sell_order_id[_token]]
                        .token_left
                )
            );
    }

    function transactionPrice(Exchange storage self, address _token, bool _type)
        internal
        view
        returns (uint256)
    {
        //Market order against market order
        //We call the getBestPrice function, which returns the lowest of
        //the last trade or the best bid
        if (
            self.orders[_token][self.first_buy_order_id[_token]].limit == 0 &&
            self.orders[_token][self.first_sell_order_id[_token]].limit == 0
        ) {
            return getBestPrice(self, _token);

            //Buy order at best vs limited sell order ==> ask price
        } else if (
            self.orders[_token][self.first_buy_order_id[_token]].limit == 0 &&
            self.orders[_token][self.first_sell_order_id[_token]].limit != 0
        ) {
            return self.orders[_token][self.first_sell_order_id[_token]].limit;

            //Limited buy order vs market sell order ==> bid price
        } else if (
            self.orders[_token][self.first_buy_order_id[_token]].limit != 0 &&
            self.orders[_token][self.first_sell_order_id[_token]].limit == 0
        ) {
            return self.orders[_token][self.first_buy_order_id[_token]].limit;

            //Limited buy order vs limited sell order
            // ==> limit placed by the counterparty not initiating the trade
        } else if (
            self.orders[_token][self.first_buy_order_id[_token]].limit != 0 &&
            self.orders[_token][self.first_sell_order_id[_token]].limit != 0
        ) {
            if (_type)
                return
                    self.orders[_token][self.first_sell_order_id[_token]].limit;
            else
                return self.orders[_token][self.first_buy_order_id[_token]].limit;
        }
    }

    function getBestPrice(Exchange storage self, address _token) public view returns (uint256 price) {
        //lowest of last paid price or lowest limit sell order
        //used to execute market orders
        bytes32 position = self.first_sell_order_id[_token];
        uint256 best_price = getLastPrice(self, _token);

        while (self.orders[_token][position].id != 0) {
            if (self.orders[_token][position].limit != 0) {
                if (self.orders[_token][position].limit < best_price) {
                    best_price = self.orders[_token][position].limit;
                }

                return best_price;
            }

            position = self.orders[_token][getNextOrder(
                self,
                _token,
                position
            )]
                .id;
        }
    }
    

    function emitOrder(
        Exchange storage self,
        address token,
        bytes32 order_id
    ) public {
        emit Placed(
            order_id,
            self.orders[token][order_id].from,
            token,
            self.orders[token][order_id].order_type,
            self.orders[token][order_id].block_nr,
            self.orders[token][order_id].eth_sent,
            self.orders[token][order_id].eth_left,
            self.orders[token][order_id].token_amount,
            self.orders[token][order_id].token_left,
            self.orders[token][order_id].limit,
            self.orders[token][order_id].previous_order,
            self.orders[token][order_id].next_order
        );
    }

    function getPreviousOrder(Exchange storage self, address _token, bytes32 _orderId)
        public
        view
        returns (bytes32)
    {
        return self.orders[_token][_orderId].previous_order;
    }

    function getNextOrder(Exchange storage self, address _token, bytes32 _orderId)
        public
        view
        returns (bytes32)
    {
        return self.orders[_token][_orderId].next_order;
    }

    function getLastPrice(Exchange storage self, address tokenAddress) public view returns (uint256) {
        return
            self.trades[tokenAddress][bytes32(
                self.trade_list[tokenAddress][getExecutionsLength(self, tokenAddress) -
                    1]
            )]
                .price;
    }

    function getExecutionsLength(Exchange storage self, address _token) public view returns (uint256) {
        return self.trade_list[_token].length;
    }

    function getOrderFrom(Exchange storage self, address _token, bytes32 _orderId)
        public
        view
        returns (address)
    {
        return self.orders[_token][_orderId].from;
    }

    // Various utils
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) return a;
        else return b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a <= b) return a;
        else return b;
    }
    
    
    function toUint256(bytes memory _bytes)   
        internal
        pure
        returns (uint256 value) {
            
        assembly {
            value := mload(add(_bytes, 0x20))
        }
        
        value = value >> (32-_bytes.length);
    }
    
}

abstract contract ERC20Interface {
    uint8 public decimals;

    string public symbol;

    string public name;

    function totalSupply() public virtual returns (uint256);

    function balanceOf(address tokenOwner)
        public
        virtual
        returns (uint256 balance);

    function allowance(address tokenOwner, address spender)
        public
        virtual
        returns (uint256 remaining);

    function transfer(address to, uint256 tokens) public virtual returns (bool success);

    function approve(address spender, uint256 tokens)
        public virtual
        returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) public virtual returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);

    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 tokens
    );
}
