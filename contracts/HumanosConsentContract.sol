// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//import 'openzeppelin-contracts/utils/math/Math.sol';

/**
 * @title ConsentContract
 * @dev ContractDescription
 * @custom:dev-run-script scripts/deploy_with_ethers.ts
 */
contract ConsentContract {
    struct ConsentTimestamps {
        uint256 startsAt;
        uint256 expiresAt;
    }

    /**
     * Address --> Hash --> ConsentTimestamps[]
     * Hash is a unique identifier for the consent, that stores what is being shared and with whom is being shared
     * ConsentTimestamps is a struct that contains the start and end time of the consent
     * Hash is unique, to identify and to block repeated consents.
     *      Instead the user can only extend the consent if still active
     *      or start a new range of time for the consent to be valid
     */
    mapping(address => mapping(bytes32 => ConsentTimestamps[])) consents;

    event ConsentGiven(
        address indexed user,
        bytes32 indexed _hash,
        uint256 length,
        uint256 startsAt,
        uint32 hoursToExpire,
        uint256 expiresAt
    );

    modifier validActiveHours(uint32 hoursToExpire) {
        require(hoursToExpire >= 3, 'At least 3 hour active');
        _;
    }

    /**
     * Gives imeadiate consent
     * @param _hash The hash of the consent
     * @param hoursToExpire The number of active hours
     * @notice must be at least one hour active
     */
    function giveImeadiateConsent(
        bytes32 _hash,
        uint32 hoursToExpire
    ) external {
        giveConsent(_hash, block.timestamp, hoursToExpire);
    }

    /**
     * Ends the consent earlier.
     * @param _hash The hash of the consent
     * @notice Can only end if the consent is still active for the more then 5 minutes
     */
    function endConsentEarlier(bytes32 _hash) external {
        uint256 length = consents[msg.sender][_hash].length;
        require(length > 0, 'No consent found');
        require(
            block.timestamp <
                consents[msg.sender][_hash][length - 1].expiresAt - 5 minutes,
            'Already expired or to close to expire'
        );
        require(
            block.timestamp > consents[msg.sender][_hash][length - 1].startsAt,
            'Consent not started yet'
        );
        consents[msg.sender][_hash][length - 1].expiresAt = block.timestamp;
    }

    /**
     * Delete a consent that didnt even started.
     * @param _hash The hash of the consent
     */
    function endConsent(bytes32 _hash) external {
        uint256 length = consents[msg.sender][_hash].length;
        require(length > 0, 'No consent found');
        require(
            block.timestamp < consents[msg.sender][_hash][length - 1].startsAt,
            'Can only end future consents'
        );
        consents[msg.sender][_hash].pop();
    }

    /**
     * Extends the consent
     * @param _hash The hash of the consent
     * @param hoursToExpire Extend by this number of hours
     * @notice hoursToExpire must be at least 1 more hour active
     * @notice Can only extend if the consent is still active
     */
    function extend(
        bytes32 _hash,
        uint32 hoursToExpire
    ) external validActiveHours(hoursToExpire) {
        uint256 length = consents[msg.sender][_hash].length;
        require(length > 0, 'No consent found');
        uint256 _expiresAt = consents[msg.sender][_hash][length - 1].expiresAt;
        require(block.timestamp < _expiresAt, 'Cant extend if already expired');
        consents[msg.sender][_hash][length - 1].expiresAt =
            _expiresAt +
            hoursToExpire *
            1 hours;
    }

    /**
     * Gives consent to a hash
     * @param _hash The hash of the consent
     * @param startsAt The time when the consent starts
     * @param hoursToExpire The number of active hours
     * @notice must be at least one hour active
     */
    function giveConsent(
        bytes32 _hash,
        uint256 startsAt,
        uint32 hoursToExpire
    ) public validActiveHours(hoursToExpire) {
        require(startsAt >= block.timestamp, 'Current time or future'); // default block.timestamp
        uint256 length = consents[msg.sender][_hash].length;
        if (length > 0) {
            // Not the first consent
            // Creating new valid consent ranges can only happen if the last one is not valid anymore
            require(
                block.timestamp >
                    consents[msg.sender][_hash][length - 1].expiresAt,
                'Last consent still valid or to be valid'
            );
        }
        uint256 expiresAt = startsAt + hoursToExpire * 1 hours;
        consents[msg.sender][_hash].push(
            ConsentTimestamps(startsAt, expiresAt)
        );
        emit ConsentGiven(
            msg.sender,
            _hash,
            length,
            startsAt,
            hoursToExpire,
            expiresAt
        );
    }

    /**
     * Checks if the consent of the caller is valid
     * @param _hash The hash of the consent
     * @return true if the consent is valid, false otherwise
     */
    function myConsentIsValid(bytes32 _hash) external view returns (bool) {
        return consentIsValid(msg.sender, _hash);
    }

    /**
     * Checks if multiple consents are vliad . Used for integrity
     * @param owners The address of the owners
     * @param _hashes The hashes of the consents
     * @return bool[] Array of booleans indicating the validity of each consent
     * @dev Efficent way to also check for integrity
     */
    function consentsAreValid(
        address[] memory owners,
        bytes32[] memory _hashes
    ) public view returns (bool[] memory) {
        require(
            _hashes.length == owners.length,
            'Hashes array should have the same size as senders array'
        );
        bool[] memory validities = new bool[](_hashes.length);
        for (uint16 i = 0; i < _hashes.length; i++) {
            validities[i] = consentIsValid(owners[i], _hashes[i]);
        }
        return validities;
    }

    /**
     * Checks if the consent of a given address is valid. Used for integrity
     * @param owner The address of the owner of the consent
     * @param _hash The hash of the consent
     * @return true if the consent is valid, false otherwise
     */
    function consentIsValid(
        address owner,
        bytes32 _hash
    ) public view returns (bool) {
        uint256 length = consents[owner][_hash].length;
        if (length == 0) return false; //"No consent found"
        if (block.timestamp < consents[owner][_hash][length - 1].startsAt)
            return false; //"Not valid yet"
        if (block.timestamp > consents[owner][_hash][length - 1].expiresAt)
            return false; //"Already Expired"
        return true;
    }

    /**
     * Get the expire
     * @param owner The address of the owner of the consent
     * @param _hash The hash of the consent
     * @return consentTimestamps The timestamps of the consent
     * @dev Used for ConsentTimestamps integrity
     */
    function getConsentTimestamps(
        address owner,
        bytes32 _hash,
        uint16 index
    ) external view returns (ConsentTimestamps memory consentTimestamps) {
        uint256 length = consents[owner][_hash].length;
        require(length > 0, 'No consent found');
        require(index < length, 'Index out of bounds');
        return consents[owner][_hash][index];
    }
}
