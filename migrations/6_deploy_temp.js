const TempStorage = artifacts.require("TempStorage");

module.exports = function (deployer) {
  deployer.deploy(TempStorage);
};
