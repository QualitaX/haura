// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IERC7586 {
    //-------------------------- Events --------------------------
    /**
    * @notice MUST be emitted when interest rates are swapped
    * @param _amount the interest difference to be transferred
    * @param _account the recipient account to send the interest difference to. MUST be either the `payer` or the `receiver`
    */
    event Swap(uint256 _amount, address _account);

    /**
    * @notice MUST be emitted when the swap contract is terminated
    * @param _payer the swap payer
    * @param _receiver the swap receiver
    */
    event TerminateSwap(address indexed _payer, address indexed _receiver);

    //-------------------------- Functions --------------------------
    /**
    *  @notice Returns the IRS `payer` account address. The party who agreed to pay fixed interest
    */
    function fixedRatePayer() external view returns(address);

    /**
    *  @notice Returns the IRS `receiver` account address. The party who agreed to pay floating interest
    */
    function floatingRatePayer() external view returns(address);

    /**
    * @notice Returns the number of decimals the swap rate and spread use - e.g. `4` means to divide the rates by `10000`
    *         To express the interest rates in basis points unit, the decimal MUST be equal to `2`. This means rates MUST be divided by `100`
    *         1 basis point = 0.01% = 0.0001
    *         ex: if interest rate = 2.5%, then swapRate() => 250 `basis points`
    */
    function ratesDecimals() external view returns(uint8);

    /**
    *  @notice Returns the fixed interest rate. All rates MUST be multiplied by 10^(ratesDecimals)
    */
    function swapRate() external view returns(uint256);

    /**
    *  @notice Returns the floating rate spread, i.e. the fixed part of the floating interest rate. All rates MUST be multiplied by 10^(ratesDecimals)
    *          floatingRate = benchmark + spread
    */
    function spread() external view returns(uint256);

    /**
    * @notice Returns the day count basis
    *         For example, 0 can denote actual/actual, 1 can denote actual/360, and so on
    */
    function dayCountBasis() external view returns(uint8);

    /**
    *  @notice Returns the contract address of the settlement currency(Example: USDC contract address).
    *          Returns the zero address if the contracct is settled in FIAT currency like USD
    */
    function settlementCurrency() external view returns(address);

    /**
    *  @notice Returns the notional amount in unit of asset to be transferred when swapping IRS. This amount serves as the basis for calculating the interest payments, and may not be exchanged
    *          Example: If the two parties aggreed to swap interest rates in USDC, then the notional amount may be equal to 1,000,000 USDC 
    */
    function notionalAmount() external view returns(uint256);

    /**
    *  @notice Returns the number of times settlement must be realized in 1 year
    */
    function settlementFrequency() external view returns(uint256);

    /**
    *  @notice Returns an array of settlement dates. Each date MUST be a Unix timestamp like the one returned by block.timestamp
    *          The length of the array returned by this function MUST equal the total number of swaps that should be realized
    *
    *  OPTIONAL
    */
    function settlementDates() external view returns(uint256[] memory);

    /**
    *  @notice Returns the starting date of the swap contract. This is a Unix Timestamp like the one returned by block.timestamp
    */
    function startingDate() external view returns(uint256);

    /**
    *  @notice Returns the maturity date of the swap contract. This is a Unix Timestamp like the one returned by block.timestamp
    */
    function maturityDate() external view returns(uint256);

    /**
    *  @notice Returns the oracle contract address for acceptable reference rates (benchmark), or the zero address when the two parties agreed to set the benchmark manually.
    *          This contract SHOULD be used to fetch real time benchmark rate
    *          Example: Contract address for `CF BIRC`
    *
    *  OPTIONAL. The two parties MAY agree to set the benchmark manually
    */
    function oracleContractForBenchmark() external view returns(address);

    /**
    *  @notice Makes swap calculation and transfers the payment to counterparties
    */
    function swap() external returns(bool);

    /**
    *  @notice Terminates the swap contract before its maturity date. MUST be called by either the `payer`or the `receiver`.
    */
    function terminateSwap() external;
}