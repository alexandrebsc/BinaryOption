// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./BinaryOption.sol";

contract Range is BinaryOption{
    struct range {
        int256 dn;
        int256 up;        
    }
    
    struct rangeOptions{
        range range;
        option[] options;
    }

    rangeOptions[] rOptions;

    modifier isValidRanges(range[] memory ranges){
        for(uint256 i=0; i<ranges.length; i++)
            for(uint256 j=0; j<ranges.length; j++)
                {
                    if(j==i)
                        continue;

                    require(((ranges[i].up < ranges[j].up && ranges[i].up < ranges[j].dn) || 
                            (ranges[i].dn > ranges[j].up && ranges[i].dn > ranges[j].dn)),
                            "There is intersection between the defined ranges");                                                
                }
        _;
    }

    constructor(address _tradeTokenAddress, address _priceAddress, uint256 _expiration,
    option[][] memory tradersOptions, range[] memory tradersRange
    )  isValidOpposits(tradersOptions) isValidRanges(tradersRange) BinaryOption(_tradeTokenAddress,_priceAddress,_expiration) {
        require(tradersOptions.length > 1, "There should be more than one group of options");
        require(tradersOptions.length == tradersRange.length, "There should be one range for each group of options");

        for (uint256 i=0; i<tradersOptions.length; i++)
            {   
                rOptions.push();
                
                for (uint256 j=0; j<tradersOptions[i].length; j++)
                    rOptions[i].options.push(tradersOptions[i][j]);

                rOptions[i].range.dn = tradersRange[i].dn;
                rOptions[i].range.up = tradersRange[i].up;
            }        
    }    

    function create() public override(BinaryOption) createModifier {
        for (uint256 i=0; i<rOptions.length; i++)
            lockBettedValues(rOptions[i].options);
    }  

    function claculatePrizes() public override(BinaryOption) claculatePrizesModifier{
        require(block.timestamp > expiration, "It isn't expired");

        int256 lastPrice = getAndValidateLatestPrice();
        
        for (uint256 i=0; i<rOptions.length; i++)
            if(lastPrice >= rOptions[i].range.dn &&
               lastPrice <= rOptions[i].range.up)
                {setPrizes(rOptions[i].options); return;}

        for (uint256 i=0; i<rOptions.length; i++)
            setRefounds(rOptions[i].options);
    }

    function viewTradersAndRanges() public view returns (string memory retorno){
        for (uint256 i=0; i<rOptions.length; i++)
            retorno = string.concat(retorno,
                                    optionsToString(rOptions[i].options),
                                    "\tRange:",Strings.toString(uint256(rOptions[i].range.dn)),
                                    " - ", Strings.toString(uint256(rOptions[i].range.up)),
                                    "\n\n");
    }
}