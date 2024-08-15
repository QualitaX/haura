// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

abstract contract ERC6123Storage {
    /*
     * Trade States
     */
    enum TradeState {

        /*
         * State before the trade is incepted.
         */
        Inactive,

        /*
         * Incepted: Trade data submitted by one party. Market data for initial valuation is set.
         */
        Incepted,

        /*
         * Confirmed: Trade data accepted by other party.
         */
        Confirmed,

        /*
         * Valuation Phase
         */
        Valuation,

        /*
         * A Token-based Transfer is in Progress
         */
        InTransfer,

        /*
         * Settlement is Completed
         */
        Settled,

        /*
         * Terminated.
         */
        Terminated
    }

    error cannotInceptWithYourself(address _inceptor, address _withParty);
    error callerMustBePayerOrReceiver(address _caller, address _payer, address _receiver);
    error invalidPositionValue(int256 _position);
    error inconsistentTradeDataOrWrongAddress(address _inceptor, uint256 _dataHash);

    modifier onlyWhenTradeInactive() {
        require(
            tradeState == TradeState.Inactive,
            "Trade state is not 'Inactive'."
        ); 
        _;
    }
    modifier onlyWhenTradeIncepted() {
        require(
            tradeState == TradeState.Incepted,
            "Trade state is not 'Incepted'."
        );
        _;
    }
    modifier onlyWhenSettled() {
        require(
            tradeState == TradeState.Settled,
            "Trade state is not 'Settled'."
        );
        _;
    }
    modifier onlyWhenValuation() {
        require(
            tradeState == TradeState.Valuation,
            "Trade state is not 'Valuation'."
        );
        _;
    }
    modifier onlyWhenInTransfer() {
        require(
            tradeState == TradeState.InTransfer,
            "Trade state is not 'InTransfer'."
        );
        _;
    }

    mapping(uint256 => address) internal pendingRequests;

    TradeState internal tradeState;
    address internal receivingParty;

    string internal tradeID;
    string internal tradeData;

    int256 terminationFee;
    int256 upfrontPayment;
}