async function lastPrice(token_address) {
  let lastPrice
  lastPrice = promisify(cb => exchange.methods.getLastPrice(token_address).call(cb))
  try {
    document.getElementById("lastPrice").innerHTML = web3.utils.fromWei(await lastPrice, "ether");
  } catch (error) {
    console.error(error);
  }
}


async function tokenBalance(token_address, client_address) {
  let tokenBalance;
  tokenBalance = promisify(cb => exchange.methods.getTokenBalance(token_address, client_address).call(cb));
  try {
    document.getElementById("tokenBalance").innerHTML = (await tokenBalance / Math.pow(10, tokenDecimals)).toFixed(4);
  } catch (error) {
    console.error(error);
  }
}

async function ethBalance(client_address) {
  let ethBalance;
  ethBalance = promisify(cb => exchange.methods.getEthBalance(client_address).call(cb));
  try {
    document.getElementById("ethBalance").innerHTML = Number(web3.utils.fromWei(String(await ethBalance), 'ether')).toFixed(4);
  } catch (error) {
    console.error(error);
  }
}

async function firstBuyOrder(token_address) {
  let firstBuyOrder;
  firstBuyOrder = promisify(cb => exchange.methods.getFirstBuyOrder(token_address).call(cb));
  try {
    return await firstBuyOrder;
  } catch (error) {
    console.error(error);
  }
}

async function firstSellOrder(token_address) {
  let firstSellOrder;
  firstSellOrder = promisify(cb => exchange.methods.getLastSellOrder(token_address).call(cb));
  try {
    return await firstSellOrder;
  } catch (error) {
    console.error(error);
  }
}

async function tokenListLength() {
  let tokenListLength;
  tokenListLength = promisify(cb => exchange.methods.getTokenListLength().call(cb));
  try {
    return await tokenListLength;
  } catch (error) {
    console.error(error);
  }
}

async function tokenAddress(pos) {
  let tokenAddress;
  tokenAddress = promisify(cb => exchange.methods.getTokenAddress(pos).call(cb));
  try {
    return await tokenAddress;
  } catch (error) {
    console.error(error);
  }
}

async function tokenSymbol(token_address) {
  let tokenSymbol;
  tokenSymbol = promisify(cb => exchange.methods.getTokenSymbol(token_address).call(cb));
  try {
    return await tokenSymbol;
  } catch (error) {
    console.error(error);
  }
}

async function getDecimals() {
  let decimals;
  decimals = promisify(cb => token.methods.decimals().call(cb));
  try {
    return await decimals;
  } catch (error) {
    console.error(error);
  }
}

async function getActiveAccount() {
  accounts = await ethereum.request({ method: 'eth_requestAccounts' });
  account = accounts[0];
  return account;
}

