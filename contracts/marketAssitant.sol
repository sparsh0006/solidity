// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract MarketAssistant {
    IPyth pyth;
    
    struct PriceData {
        bytes32 priceFeedId;
        int price;
        uint timestamp;                  
    }    
        
    constructor(address pythContract) {
        pyth = IPyth(pythContract);
    } 
    
    mapping(bytes32 => int) public priceThresholds;
    mapping(bytes32 => PriceData) public lastPrices;  
        
    event ThresholdExceeded(bytes32 indexed priceFeedId, int price);
    event PriceIncrease(bytes32 indexed priceFeedId, int previousPrice, int currentPrice, int changePercentage);
    event PriceDecrease(bytes32 indexed priceFeedId, int previousPrice, int currentPrice, int changePercentage);
    
    function updatePrice(bytes[] calldata priceUpdate, bytes32 priceFeedId) public payable returns(int) {
        uint fee = pyth.getUpdateFee(priceUpdate);     
        pyth.updatePriceFeeds{ value: fee }(priceUpdate);  
        
        PythStructs.Price memory currentPrice = pyth.getPriceNoOlderThan(priceFeedId, 60);        
        
        if (lastPrices[priceFeedId].price != 0) {
            int priceChange = calculatePriceChange(lastPrices[priceFeedId].price, currentPrice.price);
            if (priceChange > 0) {
                emit PriceIncrease(priceFeedId, lastPrices[priceFeedId].price, currentPrice.price, priceChange);
            } else if (priceChange < 0) {
                emit PriceDecrease(priceFeedId, lastPrices[priceFeedId].price, currentPrice.price, priceChange); 
            }                 
        }
        
        if (priceThresholds[priceFeedId] != 0 && currentPrice.price >= priceThresholds[priceFeedId]) {
            emit ThresholdExceeded(priceFeedId, currentPrice.price);    
        }        
        
        lastPrices[priceFeedId] = PriceData(priceFeedId,currentPrice.price, block.timestamp);        
        return currentPrice.price;     
    }  

    function calculatePriceChange(int previousPrice, int currentPrice) internal pure returns (int) {
        if (previousPrice == 0) return 0;
        return ((currentPrice - previousPrice) * 100) / previousPrice;  
    }   
    
    function setPriceThreshold(bytes32 priceFeedId, int threshold) public {
        priceThresholds[priceFeedId] = threshold;
    }    
      
}
