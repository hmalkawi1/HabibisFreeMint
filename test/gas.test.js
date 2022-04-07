// const { expect } = require("chai");

// describe("Royals", function () {
//     let deployer, user1, user2;
//     let royals;
//     let habibz;
//     let oil;
//     before(async function () {
//         [deployer, user1, user2] = await hre.ethers.getSigners();

//         const Habibz = await hre.ethers.getContractFactory("Habibi");
//         habibz = await Habibz.deploy("habibz", "hbz", "", "");
//         await habibz.setMaxMintAmount(1000);
//         await habibz.setNftPerAddressLimit(200);
//         await habibz.mint(160);
//         const OIL = await hre.ethers.getContractFactory("Oil");
//         oil = await OIL.deploy();
//         await oil.initialize(habibz.address, "0x0000000000000000000000000000000000000000");
//         await habibz.setApprovalForAll(oil.address, true);
//         await habibz.isApprovedForAll(deployer.address, oil.address);
//     });

//     beforeEach(async function () {
//         const Royals = await hre.ethers.getContractFactory("Royals");
//         royals = await Royals.deploy(habibz.address, oil.address, "", "", 3);
//         await royals.deployed();
//         await royals.setMaxMintPerWallet(100);
//     });
//     describe("Minting successfully 1 10 times", function () {
//         it("Should successfully mint 2 after burning exactly 16 staked habibz", async function () {
//             oil.setRoyalsAddress(royals.address);
//             await royals.setSaleState(2);
//             await royals.setBatchSize(100);

//             let habibzToBeBurned = [];
//             habibzToBeBurned = [];
//             for (i = 0; i < 8; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 8; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 8; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 8; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 8; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 8; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//         });
//     });
//     describe("Minting successfully 1 10 times", function () {
//         it("Should successfully mint 2 after burning exactly 16 staked habibz", async function () {
//             oil.setRoyalsAddress(royals.address);
//             await royals.setSaleState(2);
//             await royals.setBatchSize(100);
//             let habibzToBeBurned = [];
//             habibzToBeBurned = [];
//             for (i = 0; i < 16; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 16; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 16; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 16; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 16; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//             habibzToBeBurned = [];
//             for (i = 0; i < 16; i++) {
//                 habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
//             }
//             await oil.stake(habibzToBeBurned);
//             await royals.mint(habibzToBeBurned, []);
//         });
//     });
// });