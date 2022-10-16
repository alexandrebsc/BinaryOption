// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./BinaryOption.sol";

contract PriceLimit is BinaryOption{    
    option[][2] options; //index 0 betting above breakPrice | index 1 betting bellow breakPrice
    int256 breakPrice;
    int256 excludePriceRange;    

    constructor(address _tradeTokenAddress, address _priceAddress, uint256 _expiration,
    option[][] memory tradersOptions,
    int256 _breakPrice, int256 _excludePriceRange
    )  isValidOpposits(tradersOptions) BinaryOption(_tradeTokenAddress,_priceAddress,_expiration) {
        require(tradersOptions.length == 2, "There should be two group of options");        

        for (uint256 i=0; i<tradersOptions[0].length; i++)
            options[0].push(tradersOptions[0][i]);

        for (uint256 i=0; i<tradersOptions[1].length; i++)
            options[1].push(tradersOptions[1][i]);
        
        breakPrice = _breakPrice;
        excludePriceRange = _excludePriceRange;        
    }    

    function create() public override(BinaryOption) createModifier {
        for (uint256 i=0; i<options.length; i++)
            lockBettedValues(options[i]);
    }  

    function claculatePrizes() public override(BinaryOption) claculatePrizesModifier{
        require(block.timestamp > expiration, "It isn't expired");
        
        int256 lastPrice = getAndValidateLatestPrice();

        if(lastPrice > breakPrice + excludePriceRange)
            {setPrizes(options[0]); return;}
        
        if(lastPrice < breakPrice - excludePriceRange)
            {setPrizes(options[1]); return;}

        for (uint256 i=0; i<options.length; i++)
            setRefounds(options[i]);
    }

    function viewBreakPrice() public view returns (int256) {
        return breakPrice;
    }

    function viewTradersBetUp() public view returns (string memory){
        return optionsToString(options[0]);
    }

    function viewTradersBetDn() public view returns (string memory){
        return optionsToString(options[1]);
    }
}