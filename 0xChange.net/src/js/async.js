async function lastPrice(token_address) {
  let lastPrice
  lastPrice = promisify(cb => exchange.getLastPrice(token_address, cb))
  try {
    document.getElementById("lastPrice").innerHTML = web3.fromWei(await lastPrice, "ether");
  } catch (error) {
    console.error(error);
  }
}

async function fees() {
  let fees;
  fees = promisify(cb => exchange.fees(cb));
  try {
    document.getElementById("fees").innerHTML = await fees / 100;
  } catch (error) {
    console.error(error);
  }
}

async function tokenBalance(token_address, client_address) {
  let tokenBalance;
  tokenBalance = promisify(cb => exchange.free_token_balance(token_address, client_address, cb));
  try {
    document.getElementById("tokenBalance").innerHTML = (await tokenBalance / Math.pow(10, tokenDecimals)).toFixed(4);
  } catch (error) {
    console.error(error);
  }
}

async function ethBalance(client_address) {
  let ethBalance;
  ethBalance = promisify(cb => exchange.eth_balance(client_address, cb));
  try {
    document.getElementById("ethBalance").innerHTML = Number(web3.fromWei(String(await ethBalance), 'ether')).toFixed(4);
  } catch (error) {
    console.error(error);
  }
}

async function firstBuyOrder(token_address) {
  let firstBuyOrder;
  firstBuyOrder = promisify(cb => exchange.first_buy_order_id(token_address, cb));
  try {
    return await firstBuyOrder;
  } catch (error) {
    console.error(error);
  }
}

async function firstSellOrder(token_address) {
  let firstSellOrder;
  firstSellOrder = promisify(cb => exchange.first_sell_order_id(token_address, cb));
  try {
    return await firstSellOrder;
  } catch (error) {
    console.error(error);
  }
}

async function tokenListLength() {
  let tokenListLength;
  tokenListLength = promisify(cb => exchange.getTokenListLength(cb));
  try {
    return await tokenListLength;
  } catch (error) {
    console.error(error);
  }
}

async function tokenAddress(pos) {
  let tokenAddress;
  tokenAddress = promisify(cb => exchange.getTokenAddress(pos, cb));
  try {
    return await tokenAddress;
  } catch (error) {
    console.error(error);
  }
}

async function tokenSymbol(token_address) {
  let tokenSymbol;
  tokenSymbol = promisify(cb => exchange.getTokenSymbol(token_address, cb));
  try {
    return await tokenSymbol;
  } catch (error) {
    console.error(error);
  }
}

async function getDecimals() {
  let decimals;
  decimals = promisify(cb => token.decimals(cb));
  try {
    return await decimals;
  } catch (error) {
    console.error(error);
  }
}

