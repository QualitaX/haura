const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
const hre = require("hardhat");

chai.use(chaiAsPromised);
const expect = chai.expect;

describe("Interest Rate Swap", async () => {
    let irs;
    let account1;
    let account2;
    let contract;
    let settlementToken;
    let jobId = "ca98366cc7314957b8c012c72f05aeeb";
    let initialMargin;
    let terminationFee;
    let margin;
    let linkToken;
    let chainlinkOracle;

    let TradeState = {
        Inactive: 0,
        Incepeted: 1,
        Confirmed: 2,
        Valuation: 3,
        InTransfer: 4,
        Settled: 5,
        Intermination: 6,
        Terminated: 7,
        Matured: 8
    }

    beforeEach(async () => {
        [account1, account2] = await ethers.getSigners();
        initialMargin = 100;
        terminationFee = 100;
        margin = (initialMargin + terminationFee) * 1e18 + '';
        linkToken = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
        chainlinkOracle = "0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD";

        settlementToken = await hre.ethers.deployContract("SettlementToken",
            [
                "USDC Token",
                "USDC"
            ]
        );

        irs = {
            fixedRatePayer: account1.address,
            floatingRatePayer: account2.address,
            oracleContractForBenchmark: hre.ethers.ZeroAddress,
            settlementCurrency: settlementToken.target,
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

        contract = await hre.ethers.deployContract("ERC6123",
            [
                "QualitaX Token",
                "QTX",
                irs,
                linkToken,
                chainlinkOracle,
                jobId,
                initialMargin,
                terminationFee,
                1
            ]
        );
    });

    it("check IRS contract deployment has been successful", async () => {
        let address = await contract.target;

        expect(address).not.to.equal("");
    });

    it("check IRS token contract has been deployed", async () => {
        let tokenName = await contract.name();
        let tokenSymbol = await contract.symbol();
        let maxSupply = await contract.maxSupply();
        let totalSupply = await contract.totalSupply();


        expect(tokenName).to.equal("QualitaX Token");
        expect(tokenSymbol).to.equal("QTX");
        expect(Number(hre.ethers.formatEther(maxSupply))).to.equal(4);
        expect(Number(hre.ethers.formatEther(totalSupply))).to.equal(4);
    });

    it("checks counterparties IRS token balances", async () => {
        let balance1 = await contract.balanceOf(account1.address);
        let balance2 = await contract.balanceOf(account2.address);
        let totalSupply = await contract.totalSupply();

        expect(
            Number(hre.ethers.formatEther(balance1))
        ).to.equal(
            Number(hre.ethers.formatEther(totalSupply))/2
        );

        expect(
            Number(hre.ethers.formatEther(balance2))
        ).to.equal(
            Number(hre.ethers.formatEther(totalSupply))/2
        );
    });

    it("checks that we cannot mint more than max supply of the IRS token", async () => {
        expect(
            contract.mint(account1.address, "1000000000000000000")
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: reverted with custom error 'supplyExceededMaxSupply(5000000000000000000, 4000000000000000000)"
        );
    });

    it("incept an IRS trade", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        let balance1 = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance1);

        const inceptTx = await contract.connect(account1).inceptTrade(account2.address, "tradeData", 1, 100, "settlementData");

        let state = await contract.getTradeState();
        let margins = await contract.getMarginRequirement(account1.address);

        expect(state).to.equal(TradeState.Incepeted);
        expect(inceptTx).to.emit(contract, "TradeIncepted");
        expect(Number(margins.marginBuffer)).to.equal(initialMargin);
        expect(Number(margins.terminationFee)).to.equal(terminationFee);
    });

    it("confirm an IRS trade", async () => {

    });
});