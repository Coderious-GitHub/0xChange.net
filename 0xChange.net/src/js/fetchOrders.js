var eventData = [];
var orderLog = [];
var tradeLog = [];

async function fetchOrders(refresh) {
    // Empty the order log

    orderLog = [];

    // Open a new connection, using the GET request on the URL endpoint
    // Get "Placed" event log from Etherscan API
    var url = "https://api-ropsten.etherscan.io/api?module=logs&action=getLogs&" +
        "fromBlock=8446414&toBlock=latest&" +
        "address=" + exchangeAddress + "&" +
        "topic0=0x50d62adf60271dc1c915497f271dfe9c00df5c3f70f9fea2010820bbe0a06b73&" + //Placed event
        "apikey=A4NKKZFHTW1UH8T1S1WJYM5QJYYR3IDXQB";

    const ordersResponse = await fetch(url);

    if (ordersResponse.status !== 200) {
        console.log('Looks like there was a problem. Status Code: ' +
            response.status);
        return;
    }

    // Examine the text in the response
    await ordersResponse.json().then(function (data) {

        for (var i = 0; i < data.result.length; i++) {
            logData = data.result[i].data.substring(2);
            eventData = logData.match(/.{64}/g);

            orderLog.push({
                orderId: "0x" + eventData[0].toString(),
                token_address: "0x" + eventData[1].substring(24),
                block_nr: web3.toBigNumber("0x" + eventData[2].toString()).toNumber(),
                order_type: web3.toBigNumber("0x" + eventData[3].toString()).toNumber(),
                sender: "0x" + eventData[4].substring(24),
                eth_sent: parseFloat(web3.fromWei(web3.toBigNumber("0x" + eventData[5].toString()).toNumber(), "ether")).toFixed(8),
                eth_left: parseFloat(web3.fromWei(web3.toBigNumber("0x" + eventData[5].toString()).toNumber(), "ether")).toFixed(8),
                token_amount: parseFloat(web3.toBigNumber("0x" + eventData[6].toString()).toNumber() / Math.pow(10, tokenDecimals)).toFixed(8),
                token_left:  parseFloat(web3.toBigNumber("0x" + eventData[6].toString()).toNumber() / Math.pow(10, tokenDecimals)).toFixed(8),
                order_limit: parseFloat(web3.fromWei(web3.toBigNumber("0x" + eventData[7].toString()).toNumber(), "ether")).toFixed(8),
                executed: false,
                cancelled: false,
                previous_order: "0x" + eventData[8].toString(),
                next_order: "0x" + eventData[9].toString()
            });
        }

    });

    console.log(orderLog);

    updateOrders(refresh);
}

async function updateOrders(refresh) {

    // Open a new connection, using the GET request on the URL endpoint
    // Get "Traded" event log from Etherscan API
    var url = "https://api-ropsten.etherscan.io/api?module=logs&action=getLogs&" +
        "fromBlock=8446414&toBlock=latest&" +
        "address=" + exchangeAddress + "&" +
        "topic0=0xababffa2a47f95831214cc86896a4aa44bde0abc18d0b94f82f04a441ba40ebf&" + //Updated event
        "apikey=A4NKKZFHTW1UH8T1S1WJYM5QJYYR3IDXQB";

    const updateResponse = await fetch(url);

    if (updateResponse.status !== 200) {
        console.log('Looks like there was a problem. Status Code: ' +
            response.status);
        return;
    }

    // Examine the text in the response
    await updateResponse.json().then(function (data) {

        for (var i = 0; i < data.result.length; i++) {
            logData = data.result[i].data.substring(2);
            eventData = logData.match(/.{64}/g);

            let updatedOrder = "0x" + eventData[0].toString();

            for (var j = 0; j < orderLog.length; j++) {

                if (orderLog[j].orderId == updatedOrder) {
                    orderLog[j].eth_left = parseFloat(web3.fromWei(web3.toBigNumber("0x" + eventData[2].toString()).toNumber(), "ether")).toFixed(8);
                    orderLog[j].token_left = parseFloat(web3.toBigNumber("0x" + eventData[3].toString()).toNumber() / Math.pow(10, tokenDecimals)).toFixed(8);
                    orderLog[j].executed = web3.toBigNumber("0x" + eventData[4].toString()).toNumber();
                    orderLog[j].cancelled = web3.toBigNumber("0x" + eventData[5].toString()).toNumber();
                    orderLog[j].previous_order = web3.toBigNumber("0x" + eventData[6].toString()).toNumber();
                    orderLog[j].next_order = web3.toBigNumber("0x" + eventData[7].toString()).toNumber();
                    break;
                }
            }
        }
    });

    createOrderBook();
    createMyBuyOrders(refresh);
    createMySellOrders(refresh);

    if (activeChart == 0) {
        depthChart();
    }
}

async function createOrderBook() {

    var buyOrders = []
    var sellOrders = []

    for (var i = 0; i < orderLog.length; i++) {
        if (orderLog[i].token_address.toLowerCase() == activeToken &&
            orderLog[i].cancelled == false &&
            orderLog[i].executed == false &&
            orderLog[i].order_type == true) {

            buyOrders.push(orderLog[i]);

        } else if (orderLog[i].token_address.toLowerCase() == activeToken &&
            orderLog[i].cancelled == false &&
            orderLog[i].executed == false &&
            orderLog[i].order_type == false) {

            sellOrders.push(orderLog[i]);
        }
    }

    // Sort
    buyOrders.sort(function (a, b) {
        if (a.order_limit > b.order_limit) {
            return 1;
        }
        else if (a.order_limit < b.order_limit) {
            return -1;
        }
        else {
            return 0;
        }
    });

    sellOrders.sort(function (a, b) {
        if (a.order_limit > b.order_limit) {
            return 1;
        }
        else if (a.order_limit < b.order_limit) {
            return -1;
        }
        else {
            return 0;
        }
    });

    var tableClass = '"table table-hover"';
    var result = "<table class=" + tableClass + ">";

    for (var i = 0; i < buyOrders.length; i++) {
        result += "<tr class='buy-order'>";
        result += "<td>" + buyOrders[i].token_left + "</td>";

        if (parseFloat(buyOrders[i].order_limit).toFixed(8) == 0) {
            result += "<td> Best </td>"
        } else {
            result += "<td>" + parseFloat(buyOrders[i].order_limit).toFixed(8) + "</td>";
        }

        result += "</tr>";
    }

    result += "<tr class='mid-row'>";
    result += "<td>Amount</td>";
    result += "<td>Limit</td>";
    result += "</tr>";

    for (var i = 0; i < sellOrders.length; i++) {
        result += "<tr class='sell-order'>";
        result += "<td>" + sellOrders[i].token_left + "</td>";

        if (parseFloat(sellOrders[i].order_limit).toFixed(8) == 0) {
            result += "<td> Best </td>"
        } else {
            result += "<td>" + parseFloat(sellOrders[i].order_limit).toFixed(8) + "</td>";
        }

        result += "</tr>";
    }

    result += "</table>"

    document.getElementById("order-book").innerHTML = result;
}

function createMyBuyOrders(refresh) {

    var myBuyOrders = orderLog.filter(function (fil) {
        return fil.token_address.toLowerCase() == activeToken &&
            fil.sender == account && fil.order_type == 1;
    });

    myBuyOrders.reverse();

    if (!refresh) {
        $(document).ready(function () {
            var table = $('#my-buy-order-table').DataTable({
                data: myBuyOrders,
                columns: [
                    { data: "orderId" },
                    { data: "token_amount" },
                    { data: "order_limit" },
                    { data: "eth_left" },
                    { data: "token_left" },
                    { data: "executed" },
                    { data: "cancelled" },
                    { data: null },
                    { data: null },
                ],
                "scrollX": false,
                "pageLength": 5,
                "lengthMenu": [5, 10, 20, 25],
                "sEmptyTable": "No data available",
                "columnDefs": [{
                    "targets": 0,
                    "visible": false,
                    "searchable": true,
                },
                {
                    "targets": 1,
                    "title": "Amount"
                },
                {
                    "targets": 2,
                    "title": "Limit"
                },
                {
                    "targets": 3,
                    "title": "ETH Left"
                },
                {
                    "targets": 4,
                    "title": "Token Left"
                },
                {
                    "targets": 5,
                    "visible": false,
                    "searchable": false,
                },
                {
                    "targets": 6,
                    "visible": false,
                    "searchable": false,
                },
                {
                    "targets": 7,
                    "title": "Status",
                    "render": function(data, type, row, meta) {
                        if(data.executed == true)
                            return "Executed";
                        else if(data.cancelled == true)
                            return "Cancelled";
                        else 
                            return "Pending";
                    }
                },
                {
                    "targets": 8,
                    "title": "Cancel",
                    "render": function (data, type, row, meta) {
                        if(data.executed == false && data.cancelled == false) {
                            return '<input type="image" style="display:block; float:right;" src="./src/img/ic_clear_black_18dp.png"' +
                                'onclick="cancelOrder(' + "'" + data.orderId + "'" + ')">';
                        } else {
                            return "";
                        }
                    }
                }],
            });

            $('#my-buy-order-table tbody').on('click', 'image', function () {
                var data = table.row($(this).parents('tr')).data();
                alert(data);
            });

        });
    } else {
        let table = $('#my-buy-order-table').DataTable();
        let info = table.page.info();;
        $('#my-buy-order-table').dataTable().fnClearTable();
        if (myBuyOrders.length != 0) {
            $('#my-buy-order-table').dataTable().fnAddData(myBuyOrders);
            $('#my-buy-order-table').dataTable().fnPageChange(info.page);
        }
    }

}

function createMySellOrders(refresh) {

    var mySellOrders = orderLog.filter(function (fil) {
        return fil.token_address.toLowerCase() == activeToken &&
            fil.sender == account && fil.order_type == 0;
    });

    mySellOrders.reverse();

    if (!refresh) {
        $(document).ready(function () {
            var table = $('#my-sell-order-table').DataTable({
                data: mySellOrders,
                columns: [
                    { data: "orderId" },
                    { data: "token_amount" },
                    { data: "order_limit" },
                    { data: "token_left" },
                    { data: "executed" },
                    { data: "cancelled" },
                    { data: null },
                    { data: null },
                ],
                "scrollX": false,
                "pageLength": 5,
                "lengthMenu": [5, 10, 20, 25],
                "sEmptyTable": "No data available",
                "columnDefs": [{
                    "targets": 0,
                    "visible": false,
                    "searchable": true,
                },
                {
                    "targets": 1,
                    "title": "Amount"
                },
                {
                    "targets": 2,
                    "title": "Limit"
                },
                {
                    "targets": 3,
                    "title": "Token Left"
                },
                {
                    "targets": 4,
                    "visible": false,
                    "searchable": false,
                },
                {
                    "targets": 5,
                    "visible": false,
                    "searchable": false,
                },
                {
                    "targets": 6,
                    "title": "Status",
                    "render": function(data, type, row, meta) {
                        if(data.executed == true)
                            return "Executed";
                        else if(data.cancelled == true)
                            return "Cancelled";
                        else 
                            return "Pending";
                    }
                },
                {
                    "targets": 7,
                    "title": "Cancel",
                    "render": function (data, type, row, meta) {
                        if(data.executed == false && data.cancelled == false) {
                            return '<input type="image" style="display:block; float:right;" src="./src/img/ic_clear_black_18dp.png"' +
                                'onclick="cancelOrder(' + "'" + data.orderId + "'" + ')">';
                        } else {
                            return "";
                        }
                    }
                }],
            });

            $('#my-sell-order-table tbody').on('click', 'image', function () {
                var data = table.row($(this).parents('tr')).data();
                alert(data);
            });

        });
    } else {
        let table = $('#my-sell-order-table').DataTable();
        let info = table.page.info();;
        $('#my-sell-order-table').dataTable().fnClearTable();
        if (mySellOrders.length != 0) {
            $('#my-sell-order-table').dataTable().fnAddData(mySellOrders);
            $('#my-sell-order-table').dataTable().fnPageChange(info.page);
        }
    }

}

async function fetchTrades() {

    // Reinitiate the trade log
    tradeLog = [];

    // Open a new connection, using the GET request on the URL endpoint
    // Get "Placed" event log from Etherscan API
    var url = "https://api-ropsten.etherscan.io/api?module=logs&action=getLogs&" +
        "fromBlock=8446414&toBlock=latest&" +
        "address=" + exchangeAddress + "&" +
        "topic0=0xf0ce5fa6b22d2c7c2a5b03cd008b1dc37a091ca7e8c3596a87ff203bd62da8bf&" + //Traded event
        "apikey=A4NKKZFHTW1UH8T1S1WJYM5QJYYR3IDXQB";

    const tradesResponse = await fetch(url)


    if (tradesResponse.status !== 200) {
        console.log('Looks like there was a problem. Status Code: ' +
            response.status);
        return;
    }

    // Examine the text in the response
    await tradesResponse.json().then(function (data) {

        for (var i = 0; i < data.result.length; i++) {
            logData = data.result[i].data.substring(2);
            eventData = logData.match(/.{64}/g);

            tradeLog.push({
                trade_id: "0x" + eventData[0].toString(),
                token_address: "0x" + eventData[1].substring(24),
                block_nr: web3.toBigNumber("0x" + eventData[2].toString()).toNumber(),
                timestamp: web3.toBigNumber("0x" + eventData[3].toString()).toNumber(),
                order_type: web3.toBigNumber("0x" + eventData[4].toString()).toNumber(),
                buy_order_id: "0x" + eventData[5].substring(24),
                sell_order_id: "0x" + eventData[6].substring(24),
                trade_amount: web3.toBigNumber("0x" + eventData[7].toString()).toNumber(),
                trade_price: web3.toBigNumber("0x" + eventData[8].toString()).toNumber(),

            });
        }

        createTradeTable();

        if (activeChart == 1) {
            priceVolChart(activeToken);
        } else {
            prepareTradeData(tradeLog);
        }

    });

}

function createTradeTable() {

    data = tradeLog.filter(function (fil) {
        return fil.token_address.toLowerCase() == activeToken;
    })

    data.reverse();

    var buyOrder = ' class="buy-order"';
    var sellOrder = ' class="sell-order"';
    var result = "<table class='table table-hover'>";

    result += "<tbody>"

    for (var i = 0; i < data.length; i++) {

        if (data[i].order_type) {
            result += "<tr" + buyOrder + ">";
        } else {
            result += "<tr" + sellOrder + ">";
        }

        result += "<td style='width: 50%'>" + parseFloat(data[i].trade_amount / Math.pow(10, tokenDecimals)).toFixed(8) + "</td>";
        result += "<td style='width: 50%'>" + parseFloat(web3.fromWei(data[i].trade_price), "ether").toFixed(8) + "</td>";
        result += "</tr>";
    }

    result += "</tbody></table>"

    document.getElementById("trades").innerHTML = result;

}