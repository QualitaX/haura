// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

abstract contract Types {
    struct IRS {
        address irsContract;
        address fixedRatePayer;
        address floatingRatePayer;
        address oracleContractForBenchmark;
        address settlementCurrency;
        uint8 ratesDecimals;
        uint8 dayCountBasis;
        int256 swapRate;
        int256 spread;
        uint256 notionalAmount;
        uint256 settlementFrequency;
        uint256 startingDate;
        uint256 maturityDate;
        uint256[] settlementDates;
    }

    struct SettlementReceipt {
        address from;
        address to;
        address currency;
        uint256 amount;
    }

    struct MarginRequirement {
        uint256 marginBuffer;
        uint256 terminationFee;
    }
}