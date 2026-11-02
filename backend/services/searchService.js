const searchService = {
  search: (query) => ({ results: [], query: query || '', status: 'scaffold' }),
};

module.exports = searchService;
