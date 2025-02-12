// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/ShareToken.sol";

contract ShareTokenTest is Test {
    ShareToken private shareToken;
    address private owner;
    address private fundManager;
    address private user;

    function setUp() public {
        owner = address(this);
        fundManager = address(0x123);
        user = address(0x456);

        shareToken = new ShareToken("Share Token", "SHT");
        shareToken.setFundManager(fundManager);
    }

    function testInitialSetup() public view {
        assertEq(shareToken.name(), "Share Token");
        assertEq(shareToken.symbol(), "SHT");
        assertEq(shareToken.decimals(), 6);
    }

    function testSetFundManager() public {
        address newFundManager = address(0x789);

        vm.prank(owner);
        shareToken.setFundManager(newFundManager);

        // Try to mint with the new fund manager
        vm.prank(newFundManager);
        shareToken.mint(user, 1000);

        assertEq(shareToken.balanceOf(user), 1000);
    }

    function testSetFundManagerRevertIfNotOwner() public {
        address newFundManager = address(0x789);

        vm.prank(user);
        vm.expectRevert();
        shareToken.setFundManager(newFundManager);
    }

    function testMint() public {
        vm.prank(fundManager);
        shareToken.mint(user, 1000);

        assertEq(shareToken.balanceOf(user), 1000);
    }

    function testMintRevertIfNotFundManager() public {
        vm.prank(user);
        vm.expectRevert(ShareToken__NotFundManager.selector);
        shareToken.mint(user, 1000);
    }

    function testBurnFrom() public {
        vm.prank(fundManager);
        shareToken.mint(user, 1000);

        vm.prank(fundManager);
        shareToken.burnFrom(user, 500);

        assertEq(shareToken.balanceOf(user), 500);
    }

    function testBurnFromRevertIfNotFundManager() public {
        vm.prank(fundManager);
        shareToken.mint(user, 1000);

        vm.prank(user);
        vm.expectRevert(ShareToken__NotFundManager.selector);
        shareToken.burnFrom(user, 500);
    }
}
