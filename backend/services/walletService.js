const walletService = {
  getBalance: () => ({ balance: 0, transactions: [], status: 'scaffold' }),
  addMoney: () => ({ added: true, status: 'scaffold' }),
};

module.exports = walletService;
