/**
 * @description Test for AccountTriggerActionAfterDeleteVoice Apex Class
 */
@IsTest
public with sharing class AccountTriggerActionAfterDeleteVoiceTest {
    /**
     * @description FLOW test for delete account trigger
     */
    @IsTest static void deleteAccountFlowTest() {
        UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User portalAccountOwner = new User(
            UserRoleId = portalRole.Id,
            ProfileId = adminProfile.Id,
            Username = 'ned@flandcrestenterprises.com',
            Alias = 'nfland',
            Email='ned@flandcrestenterprises.com',
            EmailEncodingKey='UTF-8',
            Firstname='Ned',
            Lastname='Flanders',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            TimeZoneSidKey='America/Chicago'
        );
        insert portalAccountOwner;

        Account testAccount;
        Account testNewAccount;
        System.runAs(portalAccountOwner) {
            testAccount = new Account();
            testAccount.Name = 'The Leftorium';
            testAccount.OwnerId = portalAccountOwner.Id;
            testAccount.Account_Status__c = 'Active';
            insert testAccount;
        
            testNewAccount = new Account();
            testNewAccount.Name = 'Compu-Global-Hyper-Mega-Net';
            testNewAccount.OwnerId = portalAccountOwner.Id;
            testNewAccount.Account_Status__c = 'Active';
            insert testNewAccount;

            CallCenter callCenter = [SELECT Id FROM CallCenter LIMIT 1];
            DateTime now = DateTime.now();

            VoiceCall testVoiceCall = new VoiceCall();
            testVoiceCall.Account__c = testNewAccount.Id;
            testVoiceCall.RelatedRecordId = testAccount.Id;
            testVoiceCall.CallCenterId = callCenter.Id;
            testVoiceCall.VendorType = 'ContactCenter';
            testVoiceCall.CallStartDateTime = now;
            testVoiceCall.CallEndDateTime = now.addHours(1);
            testVoiceCall.FromPhoneNumber = '1111111111';
            testVoiceCall.ToPhoneNumber = '2222222222';
            testVoiceCall.CallType = 'Inbound';
            insert testVoiceCall;

            Test.startTest();
                Database.MergeResult result = Database.merge(testNewAccount, testAccount);
            Test.stopTest();
        }

        List<VoiceCall> voiceCallRequery = [SELECT Id, Account__c, RelatedRecordId FROM VoiceCall];
        Assert.isTrue(voiceCallRequery != null, 'We expect queried list to not be null');
        Assert.isTrue(!voiceCallRequery.isEmpty(), 'We expect queried list to not be null');
        Assert.areEqual(1, voiceCallRequery.size(), 'We expect queried list to be size 1');
        Assert.areEqual(testNewAccount.Id, voiceCallRequery[0].RelatedRecordId, 'We expect Voice Call record to be reparented');
    }
}