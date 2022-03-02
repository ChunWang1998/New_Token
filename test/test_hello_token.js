var RealBlockToken = artifacts.require('RealBlockToken');

const INITIAL_SUPPLY = 88888;
let _totalSupply;

contract('RealBlockToken', function (accounts) {
  it('should met initial supply', function () {
    var contract;
    RealBlockToken.deployed().then((instance) => {
      contract = instance;
      return contract.totalSupply.call();
    }).then((totalSupply) => {
      _totalSupply = totalSupply;
      assert.equal(totalSupply.toNumber(), INITIAL_SUPPLY);
      return contract.balanceOf(accounts[0]);
    }).then((senderBalance) => {
      assert.equal(_totalSupply.toNumber(), senderBalance.toNumber());
    });
  });
});