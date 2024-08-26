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
         * Valuation Phase: The contract is awaiting a valuation for the next settlement.
         */
        Valuation,

        /*
         * Token-based Transfer is in Progress. Contracts awaits termination of token transfer (allows async transfers).
         */
        InTransfer,

        /*
         * Settlement is Completed.
         */
        Settled,

        /*
         * Termination is in Progress.
         */
        InTermination,
        /*
         * Terminated.
         */
        Terminated
    }

    error cannotInceptWithYourself(address _inceptor, address _withParty);
    error mustBePayerOrReceiver(address _withParty, address _payer, address _receiver);
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

    modifier onlyWhenInTermination () {
        require(
            tradeState == TradeState.InTermination,
            "Trade state is not 'InTermination'."
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

    string internal tradeID;
    string internal tradeData;

    int256 terminationFee;
    int256 upfrontPayment;
}