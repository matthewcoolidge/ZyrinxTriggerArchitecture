/**
 * @description Test for ContactTriggerActionHotProspectPaidMedia Apex class
 */
@IsTest
public with sharing class ContactTriggerActionHotProspectPaidTest {
    public static Constants.User userConstants = new Constants.User();
    public static Constants.Opportunity oppConstants = new Constants.Opportunity();
    public static User DISTRIBUTABLE_BOT = [SELECT Id FROM User WHERE FirstName = 'Distributable Accounts' LIMIT 1];

    /**
     * @description FLOW test for trigger execution, Hot Prospect Contact flagged
     */
    @IsTest static void updateHotProspectContactFlowNoCreationTest() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        insert testAccount;
        
        Contact testContact = new Contact();
        testContact.LastName = 'Roadrunner';
        testContact.AccountId = testAccount.Id;
        insert testContact;

        List<Opportunity> opportunitiesBefore = [SELECT Id FROM Opportunity];

        Test.startTest();
            testContact.HotProspect__c = true;
            update testContact;
        Test.stopTest();

        List<Opportunity> actualOpportunities = [SELECT Id, Name, Hot_Opportunity__c FROM Opportunity WHERE Id NOT IN :opportunitiesBefore];
        Assert.isTrue(actualOpportunities != null, 'We expect queried list to not be null');
        Assert.isTrue(actualOpportunities.isEmpty(), 'We expect queried list to be empty as there is a previous assigned Opp');
        Assert.areEqual(0, actualOpportunities.size(), 'We expect queried list to have size 0');
    }

    @IsTest static void updateHotProspectContactFlowTest() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        testAccount.Account_Status__c = 'New Business';
        insert testAccount;
        
        Contact testContact = new Contact();
        testContact.LastName = 'Roadrunner';
        testContact.AccountId = testAccount.Id;
        insert testContact;

        Opportunity autoCreatedOpp = [SELECT Id FROM Opportunity LIMIT 1];
        autoCreatedOpp.StageName = 'Queued';
        autoCreatedOpp.OwnerId = DISTRIBUTABLE_BOT?.Id;
        update autoCreatedOpp;

        Test.startTest();
            testContact.HotProspect__c = true;
            update testContact;
        Test.stopTest();

        List<Opportunity> actualOpportunities = [SELECT Id, Name, Hot_Opportunity__c, 
                                                        OwnerId, Account.OwnerId
                                                 FROM Opportunity 
                                                 WHERE Id = :autoCreatedOpp.Id];
        Assert.isTrue(actualOpportunities != null, 'We expect queried list to not be null');
        Assert.isTrue(!actualOpportunities.isEmpty(), 'We expect queried list to not be empty');
        Assert.areEqual(1, actualOpportunities.size(), 'We expect queried list to have size 1');
        Assert.areEqual(true, actualOpportunities[0].Hot_Opportunity__c,
                        'We expect queried Opportunity to be marked Hot');
        Assert.areEqual('Hot Opportunity - Acme Inc', actualOpportunities[0].Name, 
                        'We expect queried opportunity name to be correct');
    }
    /**
     * @description FLOW test for trigger execution, Paid Media Contact flagged
     */
    @IsTest 
    static void updatePaidMediaContactFlowTest() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        testAccount.Account_Status__c = 'New Business';
        insert testAccount;
        
        Contact testContact = new Contact();

        Opportunity autoCreatedOpp = [SELECT Id FROM Opportunity LIMIT 1];
        autoCreatedOpp.StageName = 'Closed Lost';
        autoCreatedOpp.Closed_Lost_Reason__c = 'Competition'; // 90 days
        autoCreatedOpp.QTC_Closed_Lost_Details__c = 'foo';
        autoCreatedOpp.OwnerId = [SELECT Id FROM User WHERE IsActive = true AND UserType__c != :userConstants.USERTYPE_BOT LIMIT 1][0]?.Id;
        update autoCreatedOpp;

        Test.startTest();
            testContact.LastName = 'Roadrunner';
            testContact.AccountId = testAccount.Id;
            testContact.PaidMedia__c = true;
            insert testContact;
        Test.stopTest();
        
        Contact requeriedContact = [SELECT Id, PaidMedia__c FROM Contact WHERE Id = :testContact.Id];
        List<Opportunity> actualOpportunities = [SELECT Id, Name, Paid_Media_Opportunity__c FROM Opportunity WHERE Id != :autoCreatedOpp.Id];
        Assert.isTrue(actualOpportunities != null, 'We expect queried list to not be null');
        Assert.isTrue(!actualOpportunities.isEmpty(), 'We expect queried list to not be empty as its Closed Lost');
    }

    /**
     * @description Test for filterHotContacts method, Hot Prospect flagged
     */
    @IsTest static void filterHotProspectContactsTest() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        testAccount.Account_Status__c = 'New Business';
        insert testAccount;
        
        Contact testContact1 = new Contact();
        testContact1.LastName = 'Roadrunner';
        testContact1.AccountId = testAccount.Id;
        insert testContact1;

        Contact testContact2 = new Contact();
        testContact2.LastName = 'Coyote';
        testContact2.AccountId = testAccount.Id;
        insert testContact2;

        Contact clonedContact1 = testContact1.clone(true, true);
        Contact clonedContact2 = testContact2.clone(true, true);
        Map<Id, Contact> testContactOldMap = new Map<Id, Contact>();
        testContactOldMap.put(clonedContact1.Id, clonedContact1);
        testContactOldMap.put(clonedContact2.Id, clonedContact2);

        testContact1.HotProspect__c = true;
        List<Contact> testContacts = new List<Contact>{testContact1, testContact2};

        Test.startTest();
            List<Contact> filteredContacts = ContactTriggerActionHotProspectPaidMedia.filterHotContacts(testContacts, testContactOldMap);
        Test.stopTest();

        Assert.isTrue(filteredContacts != null, 'We expect returned list to not be null');
        Assert.isTrue(!filteredContacts.isEmpty(), 'We expect returned list to not be empty');
        Assert.areEqual(1, filteredContacts.size(), 'We expect returned list to have size 1');
        Assert.areEqual(testContact1.Id, filteredContacts[0].Id, 'We expect the filtered Contact to be the one with changed flag');
    }

    /**
     * @description Test for filterHotContacts method, Paid Media flagged
     */
    @IsTest static void filterPaidMediaContactsTest() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        insert testAccount;
        
        Contact testContact1 = new Contact();
        testContact1.LastName = 'Roadrunner';
        testContact1.AccountId = testAccount.Id;
        insert testContact1;

        Contact testContact2 = new Contact();
        testContact2.LastName = 'Coyote';
        testContact2.AccountId = testAccount.Id;
        insert testContact2;

        Contact clonedContact1 = testContact1.clone(true, true);
        Contact clonedContact2 = testContact2.clone(true, true);
        Map<Id, Contact> testContactOldMap = new Map<Id, Contact>();
        testContactOldMap.put(clonedContact1.Id, clonedContact1);
        testContactOldMap.put(clonedContact2.Id, clonedContact2);

        testContact1.PaidMedia__c = true;
        List<Contact> testContacts = new List<Contact>{testContact1, testContact2};

        Test.startTest();
            List<Contact> filteredContacts = ContactTriggerActionHotProspectPaidMedia.filterHotContacts(testContacts, testContactOldMap);
        Test.stopTest();

        Assert.isTrue(filteredContacts != null, 'We expect returned list to not be null');
        Assert.isTrue(!filteredContacts.isEmpty(), 'We expect returned list to not be empty');
        Assert.areEqual(1, filteredContacts.size(), 'We expect returned list to have size 1');
        Assert.areEqual(testContact1.Id, filteredContacts[0].Id, 'We expect the filtered Contact to be the one with changed flag');
    }

    /**
     * @description Test for createNewHotOpportunity method
     */
    @IsTest static void createNewHotOpportunityTest() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        insert testAccount;
        
        Contact testContact = new Contact();
        testContact.LastName = 'Roadrunner';
        testContact.AccountId = testAccount.Id;
        testContact.HotProspect__c = true;
        insert testContact;

        Test.startTest();
            Opportunity newOpportunity = ContactTriggerActionHotProspectPaidMedia.createNewHotOpportunity(testContact, testAccount);
        Test.stopTest();

        Id NEW_OPPORTUNITY_RTID = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('New').getRecordTypeId();
        Assert.isTrue(newOpportunity != null, 'We expect returned record to not be null');
        Assert.areEqual(testAccount.Id, newOpportunity.AccountId, 'We expect Opportunity Account field to be correct');
        Assert.areEqual(true, newOpportunity.Hot_Opportunity__c, 'We expect Hot Opportunity field to be correct');
        Assert.areEqual(NEW_OPPORTUNITY_RTID, newOpportunity.RecordTypeId, 'We expect Opportunity Record Type to be correct');
        Assert.areEqual('Hot Opportunity - Acme Inc', newOpportunity.Name, 'We expect Opportunity Name field to be correct');
    }

    /**
     * @description Test for insertOpportunities method, Success
     */
    @IsTest static void insertOpportunitiesTest_Success() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        insert testAccount;

        List<Opportunity> opportunitiesBefore = [SELECT Id FROM Opportunity];

        Id NEW_OPPORTUNITY_RTID = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('New').getRecordTypeId();
        Opportunity testOpportunity = new Opportunity();
        testOpportunity.Name = 'New Opportunity';
        testOpportunity.RecordTypeId = NEW_OPPORTUNITY_RTID;
        testOpportunity.AccountId = testAccount.Id;
        testOpportunity.StageName = 'Queued';
        testOpportunity.CloseDate = Date.today().addDays(30);

        Test.startTest();
            ContactTriggerActionHotProspectPaidMedia.upsertOpportunityAndAssignAccount(new List<Opportunity>{testOpportunity});
        Test.stopTest();

        List<Opportunity> actualOpportunities = [SELECT Id FROM Opportunity WHERE Id NOT IN :opportunitiesBefore];
        Assert.isTrue(actualOpportunities != null, 'We expect queried list to not be null');
        Assert.isTrue(!actualOpportunities.isEmpty(), 'Me expect queried list to not be empty');
    }

    /**
     * @description Test for insertOpportunities method, Error
     */
    @IsTest static void insertOpportunitiesTest_Error() {
        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        insert testAccount;

        List<Opportunity> opportunitiesBefore = [SELECT Id FROM Opportunity];

        Id NEW_OPPORTUNITY_RTID = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('New').getRecordTypeId();
        Opportunity testOpportunity = new Opportunity();
        testOpportunity.RecordTypeId = NEW_OPPORTUNITY_RTID;
        testOpportunity.AccountId = testAccount.Id;

        Test.startTest();
            ContactTriggerActionHotProspectPaidMedia.upsertOpportunityAndAssignAccount(new List<Opportunity>{testOpportunity});
        Test.stopTest();

        List<Zyrinx_Exception__c> exceptionList = [SELECT Id FROM Zyrinx_Exception__c];
        Assert.isTrue(exceptionList != null, 'We expect queried list to not be null');
        Assert.isTrue(!exceptionList.isEmpty(), 'We expect queried list to not be empty');
        Assert.areEqual(1, exceptionList.size(), 'We expect 1 exception record to be queried');
    }
    /*
     * @description FLOW test for trigger execution, Hot Prospect Contact flagged, testing for Task Creation
     */
    @IsTest 
    static void createTasksForContacts() {
        List <Contact> contacts = new List<Contact>();
        List <Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            Account testAccount = new Account();
            testAccount.Name = 'Acme Inc ' + i;
            accounts.add(testAccount);
        }
        insert accounts;
        for (Account acc : accounts) {
            Contact testContact = new Contact();
            testContact.LastName = 'Roadrunner ' + acc.Name;
            testContact.AccountId = acc.Id;
            contacts.add(testContact);
        }
        insert contacts;

        Test.startTest();
            List<Task> tasks = ContactTriggerActionHotProspectPaidMedia.createTasksForContacts(contacts);
        Test.stopTest();

        Map<Id, Account> accountMap = new Map<Id, Account>(accounts);
        Map<Id, Contact> contactMap = new Map<Id, Contact>(contacts);
        for (Task actualTask : tasks) {
            Assert.isTrue(contactMap.containsKey(actualTask.WhoId), 'We expect queried Task to be related to Contact');
            Assert.isTrue(accountMap.containsKey(actualTask.WhatId), 'We expect queried Task to be related to Account');
        }
    }
    @IsTest
    static void updateHotProspectContactNewBusinessTest() {
        User nonBotUser = [SELECT Id FROM User WHERE IsActive = true AND UserType__c != :userConstants.USERTYPE_BOT LIMIT 1];

        Account testAccount = new Account();
        testAccount.Name = 'Acme Inc';
        testAccount.Account_Status__c = 'New Business';
        testAccount.OwnerId = nonBotUser.Id;
        insert testAccount;

        Contact testContact = new Contact();
        testContact.LastName = 'Roadrunner';
        testContact.AccountId = testAccount.Id;
        insert testContact;

        Opportunity existingOpp = [SELECT Id FROM Opportunity WHERE AccountId = :testAccount.Id LIMIT 1];
        existingOpp.OwnerId = nonBotUser.Id;
        existingOpp.StageName = 'Queued';
        update existingOpp;

        Test.startTest();
            testContact.HotProspect__c = true;
            update testContact;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, Name, Hot_Opportunity__c, OwnerId, StageName
                                FROM Opportunity WHERE Id = :existingOpp.Id];

        System.assertNotEquals(null, updatedOpp, 'We expect the opportunity to be updated');
        System.assertEquals(true, updatedOpp.Hot_Opportunity__c, 'We expect the opportunity to be marked as Hot');
        System.assertEquals('Hot Opportunity - Acme Inc', updatedOpp.Name, 'We expect the opportunity name to be correct');
    }
}