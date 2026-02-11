// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant LIQUIDATOR_STARTING_ERC20_BALANCE = 20 ether;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE);

        ERC20Mock(weth).mint(LIQUIDATOR, LIQUIDATOR_STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(LIQUIDATOR, LIQUIDATOR_STARTING_ERC20_BALANCE);

    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(ethUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////
    // Price Tests //
    /////////////////

    function testGetUsdValue() public view {
        // 15e18 * 2,000/ETH = 30,000e18
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testIsAllowedToken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        
        vm.expectRevert();
        dsce.depositCollateral(address(0), 1);
        vm.stopPrank();
    }

    ///////////////////
    // mintDsc Tests //
    ///////////////////

    function testRevertIfMintIsZero() public depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
    }

    function testRevertIfMintBreaksHealthFactor() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        uint256 collateralUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 maxMint = (collateralUsd * dsce.getLiquidationThreshold()) / dsce.getLiquidationPrecision();

        vm.expectRevert();
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, maxMint + 1);

        vm.stopPrank();

        assertEq(dsce.getCollateralBalanceOfUser(USER), 0);
    }

    ////////////////////
    // burnDsc Tests ///
    ////////////////////

    function testBurnDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 150);
        
        dsc.approve(address(dsce), 150);
        assertEq(dsce.getDscMinted(USER), 150);

        dsce.burnDsc(50);

        vm.stopPrank();
        
        assertEq(dsce.getDscMinted(USER), 100);
    }

    ////////////////////////////
    // redeemCollateral Tests //
    ////////////////////////////

    function testRedeemCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 150);
        
        dsc.approve(address(dsce), 150);
        assertEq(dsce.getDscMinted(USER), 150);
        assertEq(dsce.getCollateralBalanceOfUserWithoutForLoop(USER, 0), AMOUNT_COLLATERAL);

        dsce.redeemCollateralForDsc(weth, 5 ether, 75);

        vm.stopPrank();
        
        assertEq(dsce.getDscMinted(USER), 75);
        assertEq(dsce.getCollateralBalanceOfUserWithoutForLoop(USER, 0), 5 ether);
    }

    ///////////////////////
    // liquidation Tests //
    ///////////////////////

    function testLiquidateIfHealthFactorIsBroken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 1000e18);
        dsc.transfer(LIQUIDATOR, 50e18);
        console.log("Health Factor Before Price Crash", dsce.getHealthFactor(USER));
        vm.stopPrank();

        // Price crashes
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(150e8);
        console.log("Health Factor After Price Crash", dsce.getHealthFactor(USER));
        assert(dsce.getHealthFactor(USER) < MIN_HEALTH_FACTOR);     

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 100e18);

        dsc.approve(address(dsce), 50e18);
        
        dsce.liquidate(weth, USER, 50e18);     
        vm.stopPrank();

        assert(dsce.getHealthFactor(USER) < MIN_HEALTH_FACTOR);
    }

    function testRevertLiquidateIfHealthFactorIsNotBroken() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 1000e18);
        dsc.transfer(LIQUIDATOR, 50e18);
        console.log("Health Factor Before Price Crash", dsce.getHealthFactor(USER));
        vm.stopPrank();  

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 100e18);

        dsc.approve(address(dsce), 50e18);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        
        dsce.liquidate(weth, USER, 50e18);     
        vm.stopPrank();

        assert(dsce.getHealthFactor(USER) > MIN_HEALTH_FACTOR);
    }

    //////////////////
    // Getter Tests //
    //////////////////

    function testGetPrecision() public view {
        uint256 PRECISION = dsce.getPrecision();
        assertEq(PRECISION, 1e18);
    }

    function testGetDscMinted() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 1e18);
        vm.stopPrank();

        uint256 dscMinted = dsce.getDscMinted(USER);
        assertEq(dscMinted, 1e18);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = dsce.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
        assertEq(collateralTokens[1], wbtc);
    }

    function testGetCollateralTokenPriceFeed() public view {
        address expectedPriceFeedAddress = dsce.getCollateralTokenPriceFeed(weth);
        assertEq(expectedPriceFeedAddress, ethUsdPriceFeed);
    }

}
