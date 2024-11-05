const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
const hre = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

chai.use(chaiAsPromised);
const expect = chai.expect;

let irs;
let account1;
let account2;
let contract;
let factory;
let contractAddressBefore;
let contractAddressAfter;
let nbOfContractsBefore;
let nbOfContractsAfter;
let settlementToken;
let jobId = "ca98366cc7314957b8c012c72f05aeeb";
let initialMargin;
let terminationFee;
let margin;
let twiceMargin;
let linkToken;
let chainlinkOracle;
let paymentAmount;
let longPosition;
let shortPosition;

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

describe("Interest Rate Swap: Deployment", async () => {
    beforeEach(async () => {
        [account1, account2] = await ethers.getSigners();
        initialMargin = 100;
        terminationFee = 100;
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
});

describe("Interest Rate Swap: Deploying with the Factory", async () => {
    beforeEach(async () => {
        [account1, account2] = await ethers.getSigners();
        initialMargin = 100;
        terminationFee = 100;
        linkToken = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
        chainlinkOracle = "0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD";

        settlementToken = await hre.ethers.deployContract("SettlementToken",
            [
                "USDC Token",
                "USDC"
            ]
        );

        factory = await hre.ethers.deployContract("SDCFactory");

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

        nbOfContractsBefore = await factory.getNumberOfContracts();
        contractAddressBefore = await factory.getIRSContract(0);

        await factory.connect(account1).deploySDCContract(
            "QualitaX Token",
            "QTX",
            irs,
            linkToken,
            chainlinkOracle,
            jobId,
            initialMargin,
            terminationFee,
            1
        );
    });

    it("check IRS contract deployment has been successful", async () => {
        nbOfContractsAfter = await factory.getNumberOfContracts();
        contractAddressAfter = await factory.getIRSContract(0);

        expect(Number(nbOfContractsAfter)).to.equal(Number(nbOfContractsBefore) + 1);
        expect(contractAddressBefore).to.equal(hre.ethers.ZeroAddress);
        expect(contractAddressAfter).not.to.equal(hre.ethers.ZeroAddress);
    });
});

describe("Interest Rate Swap: IRS Token", async () => {
    beforeEach(async () => {
        [account1, account2] = await ethers.getSigners();
        initialMargin = 100;
        terminationFee = 100;
        paymentAmount = 100;
        longPosition = 1;
        shortPosition = -1;
        margin = (initialMargin + terminationFee) * 1e18 + '';
        twiceMargin = 2 * (initialMargin + terminationFee) * 1e18 + '';
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
});

describe("Interest Rate Swap: Trade Initiation Phase", async () => {
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
    let paymentAmount;
    let longPosition;
    let shortPosition;

    beforeEach(async () => {
        [account1, account2] = await ethers.getSigners();
        initialMargin = 100;
        terminationFee = 100;
        paymentAmount = 100;
        longPosition = 1;
        shortPosition = -1;
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

    it("incept an IRS trade", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        let balance = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance);

        const inceptTx = await contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");

        let state = await contract.getTradeState();
        let margins = await contract.getMarginRequirement(account1.address);
        let contractBalance = await settlementToken.balanceOf(contract.target);
        expect(contractBalance.toString()).to.equal(balance.toString());

        expect(state).to.equal(TradeState.Incepeted);
        await expect(inceptTx).to.emit(contract, "TradeIncepted");
        expect(Number(margins.marginBuffer)).to.equal(initialMargin);
        expect(Number(margins.terminationFee)).to.equal(terminationFee);
    });

    it("cannot incept a trade without posting the initial margin and the penalty fees", async () => {
        expect(
            contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData")
        ).to.rejectedWith(
            Error,
            `VM Exception while processing transaction: reverted with custom error 'ERC20InsufficientAllowance(${account1.address}, 0, ${margin})'`
        );
    });

    it("cannot confirm a trade before inception", async () => {
        await settlementToken.connect(account2).mint(account2.address, margin);
        let balance = await settlementToken.balanceOf(account2.address);
        await settlementToken.connect(account2).approve(contract.target, balance);

        expect(
            contract.connect(account2).confirmTrade(account1.address, "tradeData", longPosition, paymentAmount, "settlementData")
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: reverted with reason string 'Trade state is not 'Incepted'."
        );

        
    });

    it("cannot confirm a trade with invalid data", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        await settlementToken.connect(account2).mint(account2.address, margin);
        let balance = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance);
        await settlementToken.connect(account2).approve(contract.target, balance);

        await contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");

        // Must be a short position, and _paymentAmount must be negative
        expect(
            contract.connect(account2).confirmTrade(account1.address, "tradeData", longPosition, paymentAmount, "settlementData")
        ).to.rejectedWith(
            Error,
            `VM Exception while processing transaction: reverted with custom error 'inconsistentTradeDataOrWrongAddress(${account1.address}, 68110287655702736617133683299303155035860407204817909534450404740929215955685)'`
        );
    });

    it("confirm an IRS trade", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        await settlementToken.connect(account2).mint(account2.address, margin);
        let balance = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance);
        await settlementToken.connect(account2).approve(contract.target, balance);

        await contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");
        const confirmTx = await contract.connect(account2).confirmTrade(account1.address, "tradeData", shortPosition, -paymentAmount, "settlementData");

        let state = await contract.getTradeState();
        let margins = await contract.getMarginRequirement(account2.address);
        let contractBalance = await settlementToken.balanceOf(contract.target);

        expect(state).to.equal(TradeState.Confirmed);
        await expect(confirmTx).to.emit(contract, "TradeConfirmed");
        expect(Number(margins.marginBuffer)).to.equal(initialMargin);
        expect(Number(margins.terminationFee)).to.equal(terminationFee);
        expect(
            contractBalance.toString()
        ).to.equal(
            twiceMargin
        );
    });

    it("cannot confirm a trade after confirmation time", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        await settlementToken.connect(account2).mint(account2.address, margin);
        let balance = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance);
        await settlementToken.connect(account2).approve(contract.target, balance);

        let inceptingTime = Date.now();
        await contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");
        await time.increaseTo(inceptingTime + 3700); // increase time over the confirmation time

        expect(
            contract.connect(account2).confirmTrade(account1.address, "tradeData", shortPosition, -paymentAmount, "settlementData")
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: reverted with reason string 'Confimartion time is over'"
        );
    });

    it("cancel a trade", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        await settlementToken.connect(account2).mint(account2.address, margin);
        let balance = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance);
        await settlementToken.connect(account2).approve(contract.target, balance);

        await contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");
        let tx = await contract.connect(account1).cancelTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");

        let state = await contract.getTradeState();

        await expect(tx).to.emit(contract, "TradeCanceled");
        expect(state).to.equal(TradeState.Inactive);
    });

    itw("cannot cancel a trade after confirmation", async () => {
        await settlementToken.connect(account1).mint(account1.address, margin);
        await settlementToken.connect(account2).mint(account2.address, margin);
        let balance = await settlementToken.balanceOf(account1.address);
        await settlementToken.connect(account1).approve(contract.target, balance);
        await settlementToken.connect(account2).approve(contract.target, balance);

        await contract.connect(account1).inceptTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData");
        await contract.connect(account2).confirmTrade(account1.address, "tradeData", shortPosition, -paymentAmount, "settlementData");

        expect(
            contract.connect(account1).cancelTrade(account2.address, "tradeData", longPosition, paymentAmount, "settlementData")
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: reverted with reason string 'Trade state is not 'Incepted'.'"
        );
    });
});