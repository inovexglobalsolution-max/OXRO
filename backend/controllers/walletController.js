const walletController = {
  getBalance: (req, res) => res.json({ balance: 0, transactions: [], status: 'scaffold' }),
  addMoney: (req, res) => res.json({ added: true, status: 'scaffold' }),
};

module.exports = walletController;
