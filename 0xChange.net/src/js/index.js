var currentBuyOrder;
var currentSellOrder;
var activeToken;
var tokenDecimals;
var trxHash;
var notifications = [];
var notifCounter = 0;

// Depth Chart defined as Chart #0 and CCandlestick as Chart #1
// Loading Depth Chart on page load
var activeChart = 0;

async function welcome() {

    $(function () {
        $('[data-toggle="popover"]').popover();
    })

    var network = window.ethereum.networkVersion;
    var account = await getActiveAccount();

    if (account == null || network != 3) {
        $('#welcomeModal').modal('show');
    } else {
        loadPage();
    }

}

async function loadPage() {

    $('#loadingModal').modal('show');

    $("#loadBar").css("width", 0 + "%");
    document.getElementById("currentPageStatus").innerHTML = "Bringing a coffee to Vitalik, brb";
    document.getElementById("notif-counter").innerHTML = notifCounter;

    $("#loadBar").css("width", 35 + "%");
    document.getElementById("currentPageStatus").innerHTML = "Loading Orders";

    await loadTokenList();
    activeToken = await tokenAddress(document.getElementById("tokenList").selectedIndex);
    activeToken = activeToken.toLowerCase();
    token = new web3.eth.Contract(tokenContract, activeToken);
    lastPrice(activeToken);
    document.getElementById("tokenSymbol").innerHTML = await tokenSymbol(await tokenAddress(document.getElementById("tokenList").selectedIndex));
    tokenDecimals = await getDecimals();

    await fetchOrders(false);

    $("#loadBar").css("width", 60 + "%");
    document.getElementById("currentPageStatus").innerHTML = "Loading Trade";

    await fetchTrades();

    $("#loadBar").css("width", 90 + "%");
    document.getElementById("currentPageStatus").innerHTML = "Loading Wallet";

    tokenBalance(activeToken, account);
    ethBalance(account);

    $("#loadBar").css("width", 100 + "%");
    document.getElementById("currentPageStatus").innerHTML = "Page Loaded";

    $('#loadingModal').modal('hide');
    $("#loadBar").css("width", 0 + "%");

}

function depthChart() {
    activeChart = 0;

    const orderData = prepareOrderData(orderLog);

    var chart = AmCharts.makeChart(document.getElementById("chart"), {
        "type": "serial",
        "theme": "dark",
        "dataProvider": orderData,
        "graphs": [{
            "id": "bids",
            "fillAlphas": 0.1,
            "lineAlpha": 1,
            "lineThickness": 2,
            "lineColor": "#0f0",
            "type": "step",
            "valueField": "bidstotalvolume",
            "balloonFunction": balloon
        }, {
            "id": "asks",
            "fillAlphas": 0.1,
            "lineAlpha": 1,
            "lineThickness": 2,
            "lineColor": "#f00",
            "type": "step",
            "valueField": "askstotalvolume",
            "balloonFunction": balloon
        }, {
            "lineAlpha": 0,
            "fillAlphas": 0.2,
            "lineColor": "#000",
            "type": "column",
            "clustered": false,
            "valueField": "bidsvolume",
            "showBalloon": false
        }, {
            "lineAlpha": 0,
            "fillAlphas": 0.2,
            "lineColor": "#000",
            "type": "column",
            "clustered": false,
            "valueField": "asksvolume",
            "showBalloon": false
        }],
        "categoryField": "value",
        "chartCursor": {},
        "balloon": {
            "textAlign": "left"
        },
        "valueAxes": [{
            "title": "Volume"
        }],
        "categoryAxis": {
            "title": "Price (ETH/" + document.getElementById("tokenList").value + ")",
            "minHorizontalGap": 100,
            "startOnAxis": true,
            "showFirstLabel": false,
            "showLastLabel": false
        },
        "export": {
            "enabled": true
        }
    });

    function balloon(item, graph) {
        var txt;
        if (graph.id == "asks") {
            txt = "Ask: <strong>" + formatNumber(item.dataContext.value, graph.chart, 4) + "</strong><br />"
                + "Total volume: <strong>" + formatNumber(item.dataContext.askstotalvolume, graph.chart, 4) + "</strong><br />"
                + "Volume: <strong>" + formatNumber(item.dataContext.asksvolume, graph.chart, 4) + "</strong>";
        }
        else {
            txt = "Bid: <strong>" + formatNumber(item.dataContext.value, graph.chart, 4) + "</strong><br />"
                + "Total volume: <strong>" + formatNumber(item.dataContext.bidstotalvolume, graph.chart, 4) + "</strong><br />"
                + "Volume: <strong>" + formatNumber(item.dataContext.bidsvolume, graph.chart, 4) + "</strong>";
        }
        return txt;
    }

    function formatNumber(val, chart, precision) {
        return AmCharts.formatNumber(
            val,
            {
                precision: precision ? precision : chart.precision,
                decimalSeparator: chart.decimalSeparator,
                thousandsSeparator: chart.thousandsSeparator
            }
        );
    }

}

function priceVolChart() {
    activeChart = 1;

    const tradeData = prepareTradeData(tradeLog);

    var chart = AmCharts.makeChart(document.getElementById("chart"), {
        "type": "serial",
        "theme": "light",
        "dataDateFormat": "DD-MM-YYYY",
        "valueAxes": [{
            "position": "left"
        }],
        "graphs": [{
            "id": "g1",
            "proCandlesticks": true,
            "balloonText": "Open:<b>[[open]]</b><br>Low:<b>[[low]]</b><br>High:<b>[[high]]</b><br>Close:<b>[[close]]</b><br>",
            "closeField": "close",
            "fillColors": "#7f8da9",
            "highField": "high",
            "lineColor": "#7f8da9",
            "lineAlpha": 1,
            "lowField": "low",
            "fillAlphas": 0.9,
            "negativeFillColors": "#db4c3c",
            "negativeLineColor": "#db4c3c",
            "openField": "open",
            "title": "Price:",
            "type": "candlestick",
            "valueField": "close"
        }],
        "chartScrollbar": {
            "graph": "g1",
            "graphType": "line",
            "scrollbarHeight": 30
        },
        "chartCursor": {
            "valueLineEnabled": true,
            "valueLineBalloonEnabled": true
        },
        "categoryField": "date",
        "categoryAxis": {
            "parseDates": true
        },
        "dataProvider": tradeData,
        "export": {
            "enabled": true,
            "position": "bottom-right"
        }
    });

    chart.addListener("rendered", zoomChart);
    zoomChart();

    // this method is called when chart is first inited as we listen for "dataUpdated" event
    function zoomChart() {
        // different zoom methods can be used - zoomToIndexes, zoomToDates, zoomToCategoryValues
        chart.zoomToIndexes(chart.dataProvider.length - 50, chart.dataProvider.length - 1);
    }
}

function placeBuyOrder() {
    var limitType = document.getElementById("buyType").value;
    var amount = document.getElementById("buyAmount").value;
    var limit = 0;

    if (limitType != "Market")
    {
        limit = web3.utils.toWei(document.getElementById("buyLimit").value, "ether");
    }

    var value = web3.utils.toWei(document.getElementById("buyValue").value, "ether");

    amount = Math.round(amount * Math.pow(10, tokenDecimals));

    exchange.methods.buy(activeToken, amount, limit)
        .send({from: account,
            value: value, 
            gasPrice: web3.utils.toWei("4", "gwei"), 
            gas: 1000000 },
        function(error, transactionHash){
            if(!error)
            {
                notifCounter += 1;
                document.getElementById("notif-counter").innerHTML = notifCounter;
                notifications.push({Status: "Pending", Type: "Buy Order", TrxHash: transactionHash})

                waitForReceipt(transactionHash, function (receipt) {
                    if (receipt) {
                        notifCounter += 1;
                        document.getElementById("notif-counter").innerHTML = notifCounter;
                        if(receipt.status == "0x1") {
                            notifications.push({Status: "Success", Type: "Buy Order", TrxHash: transactionHash})
                        } else {
                            notifications.push({Status: "Fail", Type: "Buy Order", TrxHash: transactionHash})
                        }
                    }
                });
            }
        });
}


function placeSellOrder() {
    var limitType = document.getElementById("sellType").value;
    var amount = document.getElementById("sellAmount").value;
    var limit = 0;


    if (limitType != "Market")
    {
        limit = web3.utils.toWei(document.getElementById("sellLimit").value, "ether");
    }

    amount = Math.round(amount * Math.pow(10, tokenDecimals));

    //let bytesLimit = toBytes(limit);
    var bytesLimit = web3.utils.numberToHex(limit)
    var hexLimit = "0x"

    for(i = 0; i< 64 - (bytesLimit.length - 2); i++)
    {
        hexLimit = hexLimit.concat("0");
    }

    hexLimit = hexLimit.concat(bytesLimit.substring(2, bytesLimit.length));

    token.methods.approveAndCall(exchangeAddress, amount, hexLimit)
        .send({from: account,
            gasPrice: web3.utils.toWei("4", "gwei"),
            gas: 1000000 },
        function (error, transactionHash) {
        if (!error) {
            notifCounter += 1;
            document.getElementById("notif-counter").innerHTML = notifCounter;
            notifications.push({Status: "Pending", Type: "Sell Order", TrxHash: transactionHash})
            console.log(transactionHash);

            waitForReceipt(transactionHash, function (receipt) {
                if (receipt) {
                    notifCounter += 1;
                    document.getElementById("notif-counter").innerHTML = notifCounter;
                    if(receipt.status == "0x1") {
                        notifications.push({Status: "Success", Type: "Sell Order", TrxHash: transactionHash})
                    } else {
                        notifications.push({Status: "Fail", Type: "Sell Order", TrxHash: transactionHash})
                    }
                }
            });
        }
    });
}

function withdrawToken() {
    exchange.methods.takeCoin(activeToken)
        .send({from: account,
            gasPrice: web3.utils.toWei("4", "gwei"),
            gas: 100000 },
    function (error, transactionHash) {
        if (!error) {
            notifCounter += 1;
            document.getElementById("notif-counter").innerHTML = notifCounter;
            notifications.push({Status: "Pending", Type: "Withdraw Token", TrxHash: transactionHash})
            console.log(transactionHash);

            waitForReceipt(transactionHash, function (receipt) {
                if (receipt) {
                    notifCounter += 1;
                    document.getElementById("notif-counter").innerHTML = notifCounter;
                    if(receipt.status == "0x1") {
                        notifications.push({Status: "Success", Type: "Withdraw Token", TrxHash: transactionHash})
                    } else {
                        notifications.push({Status: "Fail", Type: "Withdraw Token", TrxHash: transactionHash})
                    }
                }
            });
        }
    });
}

function withdrawEth() {
    exchange.methods.takeEth()
        .send({ from: account, gasPrice: web3.utils.toWei("4", "gwei"), gas: 100000 },
        function (error, transactionHash) {
            if (!error) {
                notifCounter += 1;
                document.getElementById("notif-counter").innerHTML = notifCounter;
                notifications.push({Status: "Pending", Type: "Withdraw ETH", TrxHash: transactionHash})
                console.log(transactionHash);

                waitForReceipt(transactionHash, function (receipt) {
                    if (receipt) {
                        notifCounter += 1;
                        document.getElementById("notif-counter").innerHTML = notifCounter;
                        if(receipt.status == "0x1") {
                            notifications.push({Status: "Success", Type: "Withdraw ETH", TrxHash: transactionHash})
                        } else {
                            notifications.push({Status: "Fail", Type: "Withdraw ETH", TrxHash: transactionHash})
                        }
                    }
                });
            }
    });
}

function cancelOrder(order_id) {
    exchange.methods.cancel(activeToken, order_id)
        .send({ from: account, gasPrice: web3.utils.toWei("4", "gwei"), gas: 500000 },
        function (error, transactionHash) {
            if (!error) {
                notifCounter += 1;
                document.getElementById("notif-counter").innerHTML = notifCounter;
                notifications.push({Status: "Pending", Type: "Cancel Order", TrxHash: transactionHash})
                console.log(transactionHash);

                waitForReceipt(transactionHash, function (receipt) {
                    if (receipt) {
                        notifCounter += 1;
                        document.getElementById("notif-counter").innerHTML = notifCounter;
                        if(receipt.status == "0x1") {
                            notifications.push({Status: "Success", Type: "Cancel Order", TrxHash: transactionHash})
                        } else {
                            notifications.push({Status: "Fail", Type: "Cancel Order", TrxHash: transactionHash})
                        }
                    }
                });
            }
    });
}

function openNotif() {
    notifCounter = 0;
    document.getElementById("notif-counter").innerHTML = notifCounter;

    var newTitle ="<div><input type='image' style='display:block; float:left;' onclick='clearNotif()' src='./src/img/ic_clear_white_18dp.png'>Clear Notification(s)</div>"
    var resultTable ="<div><table class='table table-hover' style='background-color:white'><tbody>";

    for(var i = 0; i<notifications.length; i++){
        resultTable+="<tr>";
        resultTable +="<td>" + notifications[i].Status +"</td>";
        resultTable +="<td>" + notifications[i].Type +"</td>";
        let strTrx = notifications[i].TrxHash.toString();
        resultTable +="<td style='color: #BFC0C0'>" + "<a href='https://ropsten.etherscan.io/tx/" + notifications[i].TrxHash +"' target='_blank' style='color: #BFC0C0'>" + strTrx.substring(0,8) + "..."+ "</a></td>";
        resultTable +="<tr>";
    }
    resultTable += "</tbody></table></div>"

    if(notifications.length == 0) {
        $('#notif').attr('data-original-title', newTitle);
        $('#notif').attr('data-content', "No notification");
    } else {
        $('#notif').attr('data-original-title', newTitle);
        $('#notif').attr('data-content', resultTable);
    }
}

function clearNotif(){
    notifications = [];

    var resultTable ="<div><input type='image' style='display:block; float:left;' onclick='clearNotif()' src='./src/img/ic_clear_black_18dp.png'>Clear Notification(s)</div>"
    resultTable += "<br>"
    resultTable += "<p>No notification</p>"
    $('#notif').attr('data-content', resultTable);
    $('#notif').popover('hide')
}
