module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  await deploy("WorkerToken", {
    from: deployer,
    args: [],
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["WorkerToken"];
