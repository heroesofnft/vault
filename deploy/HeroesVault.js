module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const worker = await ethers.getContract("WorkerToken");
  const hroToken = "0xBD7bd0B4650D324e3eA6f734fAA3FC37d80b7D82";
  const honToken = "0xEd2b42D3C9c6E97e11755BB37df29B6375ede3EB";
  const feeAddress = "0x75cd340028105ba5087fe8df75788c71077816b9";

  /// @param _hroToken Address of the Hro token contract
  /// @param _workerToken Address of the Worker token contract
  /// @param _honToken Address of the Hon token contract
  /// @param _feeAddress Address of the Fee account
  const { vaultAddress } = await deploy("HeroesVault", {
    from: deployer,
    args: [hroToken, worker.address, honToken, feeAddress],
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["HeroesVault"];
module.exports.dependencies = ["WorkerToken"];
