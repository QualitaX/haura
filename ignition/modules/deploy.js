const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("ERC6123Module", m => {
    let account1 = "0xA2003BF3fEbB0E8DcdEA3c75F1699b5c443Cc7cc";
    let account2 = "0x2aB0021165ed140EC25Bc320956963CA2d3dbca0";
    let zeroAddress = "0x0000000000000000000000000000000000000000";
    let jobId = "ca98366cc7314957b8c012c72f05aeeb";

    const irs = {
        fixedRatePayer: account1,
        floatingRatePayer: account2,
        oracleContractForBenchmark: hre.ethers.ZeroAddress,
        settlementCurrency: hre.ethers.ZeroAddress,
        ratesDecimals: 1,
        dayCountBasis: 0,
        swapRate: 100,
        spread: 0,
        notionalAmount: 1000,
        settlementFrequency: 360,
        startingDate: Date.now(),
        maturityDate: Date.now() + 36000,
        settlementDates: [Date.now()+2000, Date.now()+4000]
    }

    const sdc = m.contract(
        "ERC6123",
        [
            "QualitaX Token",
            "QTX",
            irs,
            "0x779877A7B0D9E8603169DdbD7836e478b4624789",
            "0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD",
            jobId,
            100,
            100,
            1
        ]
    );

    return { sdc };
});