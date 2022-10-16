// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./BinaryOption.sol";
import "hardhat/console.sol";

contract Touch is BinaryOption{
    struct touch {
        int256 priceToTouch;
        bool betTouch;        
    }
    
    struct touchOptions{
        int256 priceToTouch;
        bool betTouch;
        bool wasInitialPositionAbovePrice;
        option[] options;
    }

    touchOptions[] tOptions; 

    constructor(address _tradeTokenAddress, address _priceAddress, uint256 _expiration,
    option[][] memory tradersOptions, touch[] memory tradersTouch
    )  isValidOpposits(tradersOptions) BinaryOption(_tradeTokenAddress,_priceAddress,_expiration) {
        require(tradersOptions.length > 1, "There should be more than one group of options");
        require(tradersOptions.length <= 3, "There should be at most three group of options");        
        require(tradersOptions.length == tradersTouch.length, "There should be one touch configuration for each group of options");

        for (uint256 i=0; i<tradersOptions.length; i++)
            {   
                tOptions.push();
                
                for (uint256 j=0; j<tradersOptions[i].length; j++)
                    tOptions[i].options.push(tradersOptions[i][j]);
            } 
        
        isSetAndValidateTouches(tradersTouch);       
    }  

    function isSetAndValidateTouches(touch[] memory touches) private{
        int256 lastPrice = getLatestPrice();
        
        uint8 aboveTouchs = 0;
        uint8 bellowTouchs = 0;
        uint8 noTouchs = 0;

        for(uint256 i=0; i<touches.length; i++)
            {
                tOptions[i].priceToTouch = touches[i].priceToTouch;
                tOptions[i].betTouch = touches[i].betTouch;   

                if(!touches[i].betTouch)
                    {noTouchs++; continue;}
                
                if(touches[i].priceToTouch > lastPrice)
                    {aboveTouchs++; tOptions[i].wasInitialPositionAbovePrice=true; continue;}
                
                if(touches[i].priceToTouch < lastPrice)
                    {bellowTouchs++; tOptions[i].wasInitialPositionAbovePrice=false; continue;}

                require(touches[i].priceToTouch != lastPrice, "The touch price shouldn't be the actual price");
            }
        
        require(noTouchs <= 1 && bellowTouchs <= 1 && aboveTouchs <= 1,
                "There is conflict between the touch configurations");
    }  

    function create() public override(BinaryOption) createModifier {
        for (uint256 i=0; i<tOptions.length; i++)
            lockBettedValues(tOptions[i].options);
    }  

    function claculatePrizes() public override(BinaryOption) claculatePrizesModifier{
        int256 lastPrice = getLatestPrice();

        for (uint256 i=0; i<tOptions.length; i++)
            if((tOptions[i].betTouch && isTouchingPrice(tOptions[i], lastPrice)) ||
               (!tOptions[i].betTouch && block.timestamp > expiration))
                {setPrizes(tOptions[i].options); return;}

        for (uint256 i=0; i<tOptions.length; i++)
            setRefounds(tOptions[i].options);
    }

    function isTouchingPrice(touchOptions memory tOption, int256 lastPrice) private pure returns(bool){
        if(tOption.wasInitialPositionAbovePrice &&
            tOption.priceToTouch <= lastPrice)
            return true;
        
        if(!tOption.wasInitialPositionAbovePrice &&
            tOption.priceToTouch >= lastPrice)
            return true;
        
        return false;
    }

    function viewTradersAndTouches() public view returns (string memory retorno){
        for (uint256 i=0; i<tOptions.length; i++)
            retorno = string.concat(retorno,
                                    optionsToString(tOptions[i].options),
                                    touchToStrDetails(tOptions[i]),
                                    "\n\n");
    }

    function touchToStrDetails(touchOptions memory tOption) private pure returns(string memory retorno){
        retorno = (
            tOption.betTouch? 
            string.concat("Touch on: ",Strings.toString(uint256(tOption.priceToTouch)))
            : "No touch"
        );
    }
}