const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Consentodule", (m) => {
  const humanosContract = m.contract("ConsentContract");

  return { humanosContract };
});