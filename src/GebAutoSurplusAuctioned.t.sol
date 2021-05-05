pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebAutoSurplusAuctioned.sol";

contract GebAutoSurplusAuctionedTest is DSTest {
    GebAutoSurplusAuctioned auctioned;

    function setUp() public {
        auctioned = new GebAutoSurplusAuctioned();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
