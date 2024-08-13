// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../interfaces/IERC7586.sol";
import "./IRSToken.sol";
import "../Types.sol";

contract ERC7586 is IERC7586, IRSToken {
    constructor(
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs
    ) IRSToken(_irsTokenName, _irsTokenSymbol) {
        irs = _irs;

        uint256 balance = uint256(_irs.settlementDates.length) * 1 ether;

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

    function swap() external returns(bool) {

    }

    function terminateSwap() external {

    }
}