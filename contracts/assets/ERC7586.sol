// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IERC7586.sol";
import "./IRSToken.sol";
import "../Types.sol";

contract ERC7586 is IERC7586, IRSToken {
    AggregatorV3Interface internal ETHStakingFeed;

    constructor(
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs
    ) IRSToken(_irsTokenName, _irsTokenSymbol) {
        irs = _irs;
        ETHStakingFeed = AggregatorV3Interface(_irs.oracleContractForBenchmark);

        // one token minted for each settlement cycle per counterparty
        uint256 balance = uint256(_irs.settlementDates.length) * 1 ether;
        _maxSupply = 2 * balance;

        mint(_irs.fixedRatePayer, balance);
        mint(_irs.floatingRatePayer, balance);
    }

    function fixedRatePayer() external view returns(address) {
        return irs.fixedRatePayer;
    }

    function floatingRatePayer() external view returns(address) {
        return irs.floatingRatePayer;
    }

    function ratesDecimals() external view returns(uint8) {
        return irs.ratesDecimals;
    }

    function swapRate() external view returns(uint256) {
        return irs.swapRate;
    }

    function spread() external view returns(uint256) {
        return irs.spread;
    }

    function dayCountBasis() external view returns(uint8) {
        return irs.dayCountBasis;
    }

    function settlementCurrency() external view returns(address) {
        return irs.settlementCurrency;
    }

    function notionalAmount() external view returns(uint256) {
        return irs.notionalAmount;
    }

    function settlementFrequency() external view returns(uint256) {
        return irs.settlementFrequency;
    }

    function settlementDates() external view returns(uint256[] memory) {
        return irs.settlementDates;
    }

    function startingDate() external view returns(uint256) {
        return irs.startingDate;
    }

    function maturityDate() external view returns(uint256) {
        return irs.maturityDate;
    }

    function oracleContractForBenchmark() external view returns(address) {
        return irs.oracleContractForBenchmark;
    }


    function benchmark() public view returns(int256) {
        (
            /* uint80 roundID */,
            int stakingRate,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = ETHStakingFeed.latestRoundData();

        return stakingRate;
    }

    function swap() external returns(bool) {

    }

    function terminateSwap() external {

    }
}