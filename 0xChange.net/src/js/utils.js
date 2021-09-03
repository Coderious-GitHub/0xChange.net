var tokenList = [];

const promisify = (inner) =>
  new Promise((resolve, reject) =>
    inner((err, res) => {
      if (err) {
        reject(err);
      } else {
        resolve(res);
      }
    })
  );

function toBytes(x) {
  let bytes = "0x";

  for (var i = 0; i < x.length; i++) {

    bytes = bytes.concat("0");
    bytes = bytes.concat(x.charAt(i));

  }

  return bytes

}

function countDecimalPlaces(number) {
  var str = "" + number;
  var index = str.indexOf('.');
  if (index >= 0) {
    return str.length - index - 1;
  } else {
    return 0;
  }
}

async function loadTokenList() {

  var length = await tokenListLength();
  var list = document.getElementById("tokenList");

  for (i = 0; i < length; i++) {
    var option = document.createElement("option");
    option.text = await tokenSymbol(await tokenAddress(i));
    list.add(option);
  }

}


async function refreshPage() {

  $("#loadBar").css("width", 0 + "%");
  document.getElementById("currentPageStatus").innerHTML = "Bringing coffee to Vitalik, brb";

  $("#loadBar").css("width", 35 + "%");
  document.getElementById("currentPageStatus").innerHTML = "Loading Orders";

  activeToken = await tokenAddress(document.getElementById("tokenList").selectedIndex);
  activeToken = activeToken.toLowerCase();

  token = new web3.eth.Contract(tokenContract, activeToken);

  lastPrice(activeToken);
  document.getElementById("tokenSymbol").innerHTML = await tokenSymbol(await tokenAddress(document.getElementById("tokenList").selectedIndex));
  tokenDecimals = await getDecimals();

  await fetchOrders(true);

  $("#loadBar").css("width", 60 + "%");
  document.getElementById("currentPageStatus").innerHTML = "Loading Trade";

  await fetchTrades(true);

  $("#loadBar").css("width", 90 + "%");
  document.getElementById("currentPageStatus").innerHTML = "Loading Wallet";

  tokenBalance(activeToken, account);
  ethBalance(account);

  $("#loadBar").css("width", 100 + "%");
  document.getElementById("currentPageStatus").innerHTML = "Page Loaded";

  $('#loadingModal').modal('hide');
  $("#loadBar").css("width", 0 + "%");

}

function checkBuyOrder() {
  let amountPrecision = countDecimalPlaces(document.getElementById("buyLimit").value);
  let limitPrecision;
  let lastPricePrecision;
  let precision;
  let last_price = Number(document.getElementById("lastPrice").innerHTML);
  let value;

  if (document.getElementById("buyType").value == "Market") {
    document.getElementById("buyLimit").disabled = true;
    document.getElementById("buyLimit").value = 0.00;
    document.getElementById("buyValue").disabled = false;
    value = last_price * document.getElementById("buyAmount").value;
    lastPricePrecision = countDecimalPlaces(last_price);
    precision = amountPrecision + lastPricePrecision;
    document.getElementById("buyValue").value = value.toFixed(precision);
  } else {
    document.getElementById("buyLimit").disabled = false;
    document.getElementById("buyValue").disabled = true;
    limitPrecision = countDecimalPlaces(document.getElementById("buyAmount").value);
    precision = amountPrecision + limitPrecision;
    value = document.getElementById("buyLimit").value * document.getElementById("buyAmount").value;
    document.getElementById("buyValue").value = value.toFixed(precision);
  }
}

function checkSellOrder() {
  let amountPrecision = countDecimalPlaces(document.getElementById("sellLimit").value);
  let limitPrecision;
  let lastPricePrecision;
  let precision;
  let last_price = Number(document.getElementById("lastPrice").innerHTML);
  let value;

  if (document.getElementById("sellType").value == "Market") {
    document.getElementById("sellLimit").disabled = true;
    document.getElementById("sellLimit").value = 0.00;
  } else {
    document.getElementById("sellLimit").disabled = false;
  }
}

function padHexa(inputStr) {

  let missing = 66 - inputStr.length;

  if (missing != 0) {
    let repString = "0x"
    for (i = 0; i < missing; i++) {
      repString = repString.concat("0");
    }

    inputStr = inputStr.replace("0x", repString)

  }

  return inputStr;

}

function waitForReceipt(hash, cb) {
  web3.eth.getTransactionReceipt(hash, function (err, receipt) {
    if (err) {
      error(err);
    }
    if (receipt !== null) {
      // Transaction went through
      if (cb) {
        cb(receipt);
      }
    } else {
      // Try again in 1 second
      window.setTimeout(function () {
        waitForReceipt(hash, cb);
      }, 1000);
    }
  });
}

function prepareOrderData(orders) {

  function processData() {

    for (var i = 0; i < orders.length; i++) {
      if (orders[i].token_address.toLowerCase() == activeToken &&
        orders[i].order_type == 1 &&
        orders[i].cancelled == false &&
        orders[i].executed == false) {
        bids.push({
          value: Number(orders[i].order_limit),
          volume: Number(orders[i].order_limit * orders[i].token_left)
        })
      }

      if (orders[i].token_address.toLowerCase() == activeToken &&
        orders[i].order_type == 0 &&
        orders[i].cancelled == false &&
        orders[i].executed == false) {
        asks.push({
          value: Number(orders[i].order_limit),
          volume: Number(orders[i].order_limit * orders[i].token_left)
        })
      }
    }

    // Sort list just in case
    bids.sort(function (a, b) {
      if (a.value > b.value) {
        return 1;
      }
      else if (a.value < b.value) {
        return -1;
      }
      else {
        return 0;
      }
    });

    // Cumulate bids with same order_limit
    var cumBids = [];

    for(var i = 0; i<bids.length;i++){
      if(i==0){
        cumBids.push(bids[i]);
        continue;
      }
      if(bids[i].value == cumBids[cumBids.length-1].value){
        cumBids[cumBids.length-1].volume += bids[i].volume;
      } else {
        cumBids.push(bids[i]);
      }
    }

    asks.sort(function (a, b) {
      if (a.value > b.value) {
        return 1;
      }
      else if (a.value < b.value) {
        return -1;
      }
      else {
        return 0;
      }
    });


    // Cumulate asks with same order_limit
    var cumAsks = [];

    for(var i = 0; i<asks.length;i++){
      if(i==0){
        cumAsks.push(asks[i]);
        continue;
      }
      if(asks[i].value == cumAsks[cumAsks.length-1].value){
        cumAsks[cumAsks.length-1].volume += asks[i].volume;
      } else {
        cumAsks.push(asks[i]);
      }
    }

    //Finalize the results
    for (var i = cumBids.length - 1; i >= 0; i--) {
      if (i < (cumBids.length - 1)) {
        cumBids[i].totalvolume = cumBids[i + 1].totalvolume + cumBids[i].volume;
      }
      else {
        cumBids[i].totalvolume = cumBids[i].volume;
      }
      var dp = {};
      dp["value"] = cumBids[i].value;
      dp["bidsvolume"] = cumBids[i].volume;
      dp["bidstotalvolume"] = cumBids[i].totalvolume;
      res.unshift(dp);
    }

    for (var i = 0; i < cumAsks.length; i++) {
      if (i > 0) {
        cumAsks[i].totalvolume = cumAsks[i - 1].totalvolume + cumAsks[i].volume;
      }
      else {
        cumAsks[i].totalvolume = cumAsks[i].volume;
      }
      var dp = {};
      dp["value"] = cumAsks[i].value;
      dp["asksvolume"] = cumAsks[i].volume;
      dp["askstotalvolume"] = cumAsks[i].totalvolume;
      res.push(dp);
    }
  }

  // Init
  var bids = [];
  var asks = [];
  var res = [];

  processData();

  return res;
}

function prepareTradeData(data) {

  function processData() {

    data = data.filter(function (fil) {
      return fil.token_address.toLowerCase() == activeToken;
    })

    if (data.length == 0) {
      return;
    }

    let currentDay = new Date(data[0].timestamp * 1000).toLocaleDateString("en-US");
    let open = web3.utils.fromWei(data[0].trade_price, "ether");
    let high = web3.utils.fromWei(data[0].trade_price, "ether");
    let low = web3.utils.fromWei(data[0].trade_price, "ether");
    let close = web3.utils.fromWei(data[0].trade_price, "ether");
    let volume = web3.utils.fromWei(data[0].trade_price, "ether") * data[0].trade_amount;
    let missingZeroMonth;
    let missingZeroDate;

    for (var i = 1; i < data.length; i++) {
      let newDate = new Date(data[i].timestamp * 1000).toLocaleDateString("en-US");

      if (newDate != currentDay) {
        close = web3.utils.fromWei(data[i - 1].trade_price, "ether");

        let date = new Date(currentDay);

        if (date.getMonth() < 9) {
          missingZero = "0";
        } else {
          missingZero = "";
        }

        if (date.getDate() < 10) {
          missingZeroDate = "0";
        } else {
          missingZeroDate = "";
        }

        res.push({
          "date": missingZeroDate + date.getDate() + "-" + missingZero + (date.getMonth() + 1) + "-" + date.getFullYear(),
          "open": open,
          "high": high,
          "low": low,
          "close": close,
          "volume": volume
        })

        currentDay = new Date(data[i].timestamp * 1000).toLocaleDateString("en-US");
        open = web3.utils.fromWei(data[i].trade_price, "ether");
        high = web3.utils.fromWei(data[i].trade_price, "ether");
        low = web3.utils.fromWei(data[i].trade_price, "ether");
        close = web3.utils.fromWei(data[i].trade_price, "ether");
        volume = web3.utils.fromWei(data[i].trade_price, "ether") * data[i].trade_amount;

      } else {
        volume += web3.utils.fromWei(data[i].trade_price, "ether") * data[i].trade_amount;
        if (web3.utils.fromWei(data[i].trade_price, "ether") > high) {
          high = web3.utils.fromWei(data[i].trade_price, "ether");
        }

        if (web3.utils.fromWei(data[i].trade_price, "ether") < low) {
          low = web3.utils.fromWei(data[i].trade_price, "ether");
        }
      }
    }

    close = web3.utils.fromWei(data[data.length - 1].trade_price, "ether");

    let date = new Date(currentDay);

    if (date.getMonth() < 9) {
      missingZeroMonth = "0";
    } else {
      missingZeroMonth = "";
    }

    if (date.getDate() < 10) {
      missingZeroDate = "0";
    } else {
      missingZeroDate = "";
    }

    res.push({
      "date": missingZeroDate + date.getDate() + "-" + missingZeroMonth + (date.getMonth() + 1) + "-" + date.getFullYear(),
      "open": open,
      "high": high,
      "low": low,
      "close": close,
      "volume": volume
    })

  }

  // Init
  var res = [];

  processData()

  if (res.length != 0) {
    document.getElementById("dayVolume").innerHTML = parseFloat(res[res.length - 1].volume / Math.pow(10, tokenDecimals)).toFixed(8) + " ETH";
  } else {
    document.getElementById("dayVolume").innerHTML = "No data available";
  }

  return res;
}