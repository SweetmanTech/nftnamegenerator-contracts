// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../interfaces/IERC721Drop.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {NFTMetadataRenderer} from "../utils/NFTMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";
import {INFTNameGenMetadataRenderer} from "../interfaces/INFTNameGenMetadataRenderer.sol";

interface DropConfigGetter {
    function config()
        external
        view
        returns (IERC721Drop.Configuration memory config);
}

/// @notice NFTNameGenMetadataRenderer for allow list support
contract NFTNameGenMetadataRenderer is
    INFTNameGenMetadataRenderer,
    MetadataRenderAdminCheck
{
    /// @notice Storage for token edition information
    struct TokenEditionInfo {
        string description;
        string imageURI;
        string animationURI;
    }

    /// @notice Event for updated Media URIs
    event MediaURIsUpdated(
        address indexed target,
        address sender,
        string imageURI,
        string animationURI
    );

    /// @notice Event for a new edition initialized
    /// @dev admin function indexer feedback
    event EditionInitialized(
        address indexed target,
        string description,
        string imageURI,
        string animationURI
    );

    /// @notice Description updated for this edition
    /// @dev admin function indexer feedback
    event DescriptionUpdated(
        address indexed target,
        address sender,
        string newDescription
    );

    struct TokenInfo {
        string name;
        string description;
        string imageURL;
    }

    /// @notice Token information mapping storage
    mapping(address => TokenEditionInfo) public tokenInfos;
    /// @notice Token form response mapping storage
    mapping(address => mapping(uint256 => TokenInfo)) public tokenInfo;

    /// @notice Update media URIs
    /// @param target target for contract to update metadata for
    /// @param imageURI new image uri address
    /// @param animationURI new animation uri address
    function updateMediaURIs(
        address target,
        string memory imageURI,
        string memory animationURI
    ) external requireSenderAdmin(target) {
        tokenInfos[target].imageURI = imageURI;
        tokenInfos[target].animationURI = animationURI;
        emit MediaURIsUpdated({
            target: target,
            sender: msg.sender,
            imageURI: imageURI,
            animationURI: animationURI
        });
    }

    /// @notice Admin function to update description
    /// @param target target description
    /// @param newDescription new description
    function updateDescription(address target, string memory newDescription)
        external
        requireSenderAdmin(target)
    {
        tokenInfos[target].description = newDescription;

        emit DescriptionUpdated({
            target: target,
            sender: msg.sender,
            newDescription: newDescription
        });
    }

    /// @notice Admin function to set token info
    /// @param tokenId token id to set token info for
    /// @param description description to set
    /// @param name name to set
    /// @param imageURL image url to set
    function setTokenInfo(
        uint256 tokenId,
        string memory name,
        string memory description,
        string memory imageURL
    ) external requireSenderAdmin(msg.sender) {
        address target = msg.sender;
        tokenInfo[target][tokenId] = TokenInfo({
            name: name,
            description: description,
            imageURL: imageURL
        });
    }

    /// @notice Default initializer for edition data from a specific contract
    /// @param data data to init with
    function initializeWithData(bytes memory data) external {
        // data format: description, imageURI, animationURI
        (
            string memory description,
            string memory imageURI,
            string memory animationURI
        ) = abi.decode(data, (string, string, string));

        tokenInfos[msg.sender] = TokenEditionInfo({
            description: description,
            imageURI: imageURI,
            animationURI: animationURI
        });
        emit EditionInitialized({
            target: msg.sender,
            description: description,
            imageURI: imageURI,
            animationURI: animationURI
        });
    }

    /// @notice Contract URI information getter
    /// @return contract uri (if set)
    function contractURI() external view override returns (string memory) {
        address target = msg.sender;
        TokenEditionInfo storage editionInfo = tokenInfos[target];
        IERC721Drop.Configuration memory config = DropConfigGetter(target)
            .config();

        return
            NFTMetadataRenderer.encodeContractURIJSON({
                name: IERC721MetadataUpgradeable(target).name(),
                description: editionInfo.description,
                imageURI: editionInfo.imageURI,
                royaltyBPS: uint256(config.royaltyBPS),
                royaltyRecipient: config.fundsRecipient
            });
    }

    /// @notice Token URI information getter
    /// @param tokenId to get uri for
    /// @return contract uri (if set)
    function tokenURI(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        address target = msg.sender;
        TokenEditionInfo memory info = tokenInfos[target];
        IERC721Drop media = IERC721Drop(target);

        uint256 maxSupply = media.saleDetails().maxSupply;

        // For open editions, set max supply to 0 for renderer to remove the edition max number
        // This will be added back on once the open edition is "finalized"
        if (maxSupply == type(uint64).max) {
            maxSupply = 0;
        }

        return
            NFTMetadataRenderer.createMetadataEdition({
                name: tokenId > 0
                    ? tokenInfo[target][tokenId].name
                    : IERC721MetadataUpgradeable(target).name(),
                description: tokenInfo[target][tokenId].description,
                imageUrl: tokenInfo[target][tokenId].imageURL,
                animationUrl: info.animationURI,
                tokenOfEdition: tokenId,
                editionSize: maxSupply
            });
    }
}
