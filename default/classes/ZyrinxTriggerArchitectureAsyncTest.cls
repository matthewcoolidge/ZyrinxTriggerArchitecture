@isTest
public without sharing class ZyrinxTriggerArchitectureAsyncTest extends ZyrinxTriggerArchitecture.asyncProcessing implements ZyrinxTriggerArchitecture.executeMethod, ZyrinxTriggerArchitecture.triggerCache {

    public static List<String> output = new List<String>();

    public static void init(String action){

        System.debug('ZyrinxTriggerArchitectureAsyncTest.init - ' + action);
        output.add('ZyrinxTriggerArchitectureAsyncTest.init - ' + action);
    }

    public void execute(List <sObject> records, Map <id, sObject> oldMap, ZyrinxTriggerArchitecture.triggerParameters tp)
    {
        System.debug('ZyrinxTriggerArchitectureAsyncTest.execute');

        Integer count = records.size();

        Id user1 = UserInfo.getUserId();

        // When we INSERT anything, we will:
        // 1) INSERT an Account
        // 2) INSERT an Opportunity
        // 3) SEND an Email
        // Obviously this isnt a very realistic example......
        if(tp.isInsert){
            for(SObject o : records){
                if(tp.isAfter){
                    insertObject(new Contact(LastName='AsyncTestINSERT' + Math.random()));
                    insertObjects(new List<Opportunity>{new Opportunity(Name='AsyncTestINSERT' + Math.random(), 
                        Stagename='New', CloseDate=date.today(), Type='New', LeadSource='Other', OwnerId = UserInfo.getUserId())});

                    Messaging.SingleEmailMessage newEmail = new Messaging.SingleEmailMessage();
                    newEmail.setTargetObjectId(user1);
                    newEmail.setSaveAsActivity(false);
                    newEmail.setSubject('ZyrinxTriggerArchitectureAsyncTest.execute');
                    newEmail.setHtmlBody('ZyrinxTriggerArchitectureAsyncTest.execute');
                    mailObject(newEmail); 

                    Messaging.SingleEmailMessage newEmail2 = new Messaging.SingleEmailMessage();
                    newEmail2.setTargetObjectId(user1);
                    newEmail2.setSaveAsActivity(false);
                    newEmail2.setSubject('ZyrinxTriggerArchitectureAsyncTest.execute2');
                    newEmail2.setHtmlBody('ZyrinxTriggerArchitectureAsyncTest.execute2');
                    mailObjects(new List<Messaging.SingleEmailMessage>{newEmail2}); 
                }
            }
        }
        else if (tp.IsUpdate){
            Set<Id> accountIds = new Set<Id>();
            for(SObject o : records){
                if(tp.isAfter){
                    Account acct = (Account)o;
                    accountIds.add(acct.Id);
                }
            }
            if(tp.isAfter){
                List<Contact> updateContacts = [SELECT Id, lastname FROM Contact WHERE AccountId IN :accountIds];
                for(Contact c : updateContacts){
                    c.LastName = 'UPDATED' + c.LastName;
                    updateObject(c);
                }
                List<Opportunity> updateOpportunities = [SELECT Id, Name FROM Opportunity WHERE AccountId IN :accountIds];
                for(Opportunity o : updateOpportunities){
                    o.Name = 'UPDATED' + o.Name;
                }
                updateObjects(updateOpportunities);
            }
        }
        else if (tp.isDelete){
            Set<Id> accountIds = new Set<Id>();
            for(SObject o : records){
                if(tp.isAfter){
                    Account acct = (Account)o;
                    accountIds.add(acct.Id);
                }
            }
            if(tp.isAfter){
                List<Contact> deleteContacts = [SELECT Id, Lastname FROM Contact WHERE AccountId IN :accountIds];
                deleteObjects(deleteContacts);
                Opportunity deleteOpportunity = [SELECT Id, Name FROM Opportunity LIMIT 1];
                deleteObject(deleteOpportunity);
            }          
        }
    }

    private static testmethod void testGetTriggerActions(){

        List<Trigger_Action__mdt> triggerActions = ZyrinxTriggerArchitectureMetadataService.getTriggerActions();
        System.assertNotEquals(null, triggerActions);
    }

    private static testmethod void testGetSynchronousRecordLimit(){

        ZyrinxTriggerArchitectureMetadataService.mapTriggerSettings = new Map<String, Trigger_Settings_Zyrinx__mdt>();
        Integer lim = ZyrinxTriggerArchitectureMetadataService.getSynchronousRecordLimit();
        Assert.areEqual(1, lim);

        Trigger_Settings_Zyrinx__mdt defaultSettings = new Trigger_Settings_Zyrinx__mdt();
        defaultSettings.MasterLabel = 'Default';
        ZyrinxTriggerArchitectureMetadataService.mapTriggerSettings = new Map<String, Trigger_Settings_Zyrinx__mdt>{'Foo'=>defaultSettings};
        lim = ZyrinxTriggerArchitectureMetadataService.getSynchronousRecordLimit();
        Assert.areEqual(1, lim);

        ZyrinxTriggerArchitectureMetadataService.mapTriggerSettings = new Map<String, Trigger_Settings_Zyrinx__mdt>{'Default'=>defaultSettings};
        lim = ZyrinxTriggerArchitectureMetadataService.getSynchronousRecordLimit();
        Assert.areEqual(1, lim);

        defaultSettings.SynchronousRecordLimit__c = 99;
        ZyrinxTriggerArchitectureMetadataService.mapTriggerSettings = new Map<String, Trigger_Settings_Zyrinx__mdt>{'Default'=>defaultSettings};
        lim = ZyrinxTriggerArchitectureMetadataService.getSynchronousRecordLimit();
        Assert.areEqual(99, lim);
    }

    private static testmethod void testBulkInsertArchitectureTestAsyncSingle(){

        // This test should revert to Synchronous DML, assuming SYNCRONOUS_RECORD_LIMIT is 1

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        ZyrinxTriggerArchitectureSetting__c tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=false, Expanded_Debugging__c = true);
        insert tes;

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.BlockRecursion__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';
        
        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<1; x++){
            Account a = new Account();
            a.Name = 'TestAccount' + String.valueOf(x);
            a.Phone = String.valueOf(x) + '239654125';
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            a.OwnerId = UserInfo.getUserId();
            accounts.add(a);
        }

        // We are inserting mixed DML (Contacts and Opportunities) for every Account
        Test.startTest();
        insert accounts;
        Test.stopTest();

        Assert.areEqual(false, ZyrinxTriggerArchitecture.allowAsynchronousProcessing);

        List<Contact> newContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'AsyncTestINSERT%'];
        Assert.areEqual(1, newContacts.size());

        List<Opportunity> newOpportunities = [SELECT Id, Name FROM Opportunity WHERE Name LIKE 'AsyncTestINSERT%'];
        Assert.areEqual(1, newOpportunities.size());
    }

    private static testmethod void testBulkInsertArchitectureTestAsync(){

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<5; x++){
            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            a.OwnerId = UserInfo.getUserId();
            accounts.add(a);
        }

        ZyrinxTriggerArchitectureSetting__c tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=false, Expanded_Debugging__c = true);
        insert tes;

        // We are inserting mixed DML (Contacts and Opportunities) for every Account
        Test.startTest();
        insert accounts;
        Test.stopTest();

        Assert.areEqual(true, ZyrinxTriggerArchitecture.allowAsynchronousProcessing);
        List<Contact> newContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'AsyncTestINSERT%'];
        Assert.areEqual(5, newContacts.size());

        List<Opportunity> newOpportunities = [SELECT Id, Name FROM Opportunity WHERE Name LIKE 'AsyncTestINSERT%'];
        Assert.areEqual(5, newOpportunities.size());
    }

    private static testmethod void testBulkUpdateArchitectureTestAsyncSingle(){

        // This test should revert to Synchronous DML, assuming SYNCRONOUS_RECORD_LIMIT is 1

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        ZyrinxTriggerArchitectureSetting__c tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=true, Expanded_Debugging__c = false);
        insert tes;

        List<Account> setupData = new List<Account>();
        for (Integer x = 0; x<1; x++){
            Account a = new Account();
            a.Name = 'TestAccount' + x;
            a.Phone = String.valueOf(x) + '239654125';
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            a.OwnerId = UserInfo.getUserId();
            setupData.add(a);
        }
        insert setupData;

        List<Contact> contacts = new List<Contact>();
        for (Integer x = 0; x<1; x++){
            Contact c = new Contact();
            c.LastName = 'TestContact' + x;
            c.AccountId = setupData[x].Id;
            contacts.add(c);
        }
        insert contacts;

        delete tes;

        tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=false, Expanded_Debugging__c = true);
        insert tes;

        for (Integer x = 0; x<1; x++){
            setupData[x].Name = 'UPDATED TestAccount' + x;
        }

        // We want to affect the Contact for each Account updated, asyncronously
        Test.startTest();
        update setupData;
        Test.stopTest();

        Assert.areEqual(false, ZyrinxTriggerArchitecture.allowAsynchronousProcessing);
        List<Contact> cont = new List<Contact>([SELECT id, lastname from contact]);
        system.debug('cont' + cont);
        List<Contact> updatedContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'UPDATED%'];
        Assert.areEqual(1, updatedContacts.size());
    }

    private static testmethod void testBulkUpdateArchitectureTestAsync(){

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};
        
        ZyrinxTriggerArchitectureSetting__c tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=true, Expanded_Debugging__c = false);
        insert tes;

        List<Account> setupData = new List<Account>();
        for (Integer x = 0; x<5; x++){
            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            a.OwnerId = UserInfo.getUserId();
            setupData.add(a);
        }
        insert setupData;

        List<Contact> contacts = new List<Contact>();
        for (Integer x = 0; x<5; x++){
            Contact c = new Contact();
            c.LastName = 'TestContact' + x;
            c.AccountId = setupData[x].Id;
            contacts.add(c);
        }
        insert contacts;

        delete tes;

        tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=false, Expanded_Debugging__c = true);
        insert tes;

        for (Integer x = 0; x<5; x++){
            setupData[x].Name = 'UPDATED TestAccount' + x;
        }

        // We want to affect the Contact for each Account updated, asyncronously
        Test.startTest();
        update setupData;
        Test.stopTest();

        Assert.areEqual(true, ZyrinxTriggerArchitecture.allowAsynchronousProcessing);

        List<Contact> updatedContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'UPDATED%'];
        Assert.areEqual(5, updatedContacts.size());
    }

    private static testmethod void testBulkDeleteArchitectureTestAsyncSingle(){

        // This test should revert to Synchronous DML, assuming SYNCRONOUS_RECORD_LIMIT is 1

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterDelete__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        ZyrinxTriggerArchitectureSetting__c tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=true, Expanded_Debugging__c = false);
        insert tes;

        List<Account> setupData = new List<Account>();
        for (Integer x = 0; x<1; x++){
            Account a = new Account();
            a.Name = 'TestAccount' + x;
            a.Phone = String.valueOf(x) + '239654125';
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            a.OwnerId = UserInfo.getUserId();
            setupData.add(a);
        }
        insert setupData;

        List<Contact> contacts = new List<Contact>();
        for (Integer x = 0; x<1; x++){
            Contact c = new Contact();
            c.LastName = 'TestContact' + x;
            c.AccountId = setupData[x].Id;
            c.OwnerId = UserInfo.getUserId();
            contacts.add(c);
        }
        insert contacts;

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer x = 0; x<1; x++){
            Opportunity o = new Opportunity();
            o.Name = 'TestOpp' + x;
            o.StageName = 'New';
            o.CloseDate = Date.today();
            o.OwnerId = UserInfo.getUserId();
            //o.AccountId = setupData[x].Id;
            opportunities.add(o);
        }
        insert opportunities;

        delete tes;

        tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=false, Expanded_Debugging__c = true);
        insert tes;

        // We want to affect the Contact for each Account deleted, syncronously
        Test.startTest();
        delete [SELECT Id FROM QTCBusiness_Profile__c WHERE QTCAccount_Name__c IN :setupData];
        delete setupData;
        Test.stopTest();

        Assert.areEqual(false, ZyrinxTriggerArchitecture.allowAsynchronousProcessing);

        List<Contact> deletedContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'TestContact%'];
        Assert.areEqual(0, deletedContacts.size());
    }

    private static testmethod void testBulkDeleteArchitectureTestAsync(){

        // This test should revert to Synchronous DML, assuming SYNCRONOUS_RECORD_LIMIT is 1

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterDelete__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        ZyrinxTriggerArchitectureSetting__c tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=true, Expanded_Debugging__c = false);
        insert tes;

        List<Account> setupData = new List<Account>();
        for (Integer x = 0; x<5; x++){
            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            a.OwnerId = UserInfo.getUserId();
            setupData.add(a);
        }
        insert setupData;

        List<Contact> contacts = new List<Contact>();
        for (Integer x = 0; x<5; x++){
            Contact c = new Contact();
            c.LastName = 'TestContact' + x;
            c.AccountId = setupData[x].Id;
            c.OwnerId = UserInfo.getUserId();
            contacts.add(c);
        }
        insert contacts;

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer x = 0; x<5; x++){
            Opportunity o = new Opportunity();
            o.Name = 'TestOpp' + x;
            o.StageName = 'New';
            o.CloseDate = Date.today();
            //o.AccountId = setupData[x].Id;
            opportunities.add(o);
        }
        insert opportunities;

        delete tes;

        tes = new ZyrinxTriggerArchitectureSetting__c(SetupOwnerid=UserInfo.getUserId(), Block_Triggers__c=false, Expanded_Debugging__c = true);
        insert tes;

        // We want to affect the Contact for each Account deleted, asyncronously
        Test.startTest();
        delete [SELECT Id FROM QTCBusiness_Profile__c WHERE QTCAccount_Name__c IN :setupData];
        delete setupData;
        Test.stopTest();

        Assert.areEqual(true, ZyrinxTriggerArchitecture.allowAsynchronousProcessing);

        List<Contact> deletedContacts = [SELECT Id, LastName FROM Contact WHERE LastName LIKE 'TestContact%'];
        Assert.areEqual(0, deletedContacts.size());
    }

    private static testmethod void testEmailArchitectureTestAsync(){

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<1; x++){
            Account a = new Account();
            a.Name = 'TestAccount' + x;
            a.Phone = String.valueOf(x) + '239654125';
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            a.OwnerId = UserInfo.getUserId();
            accounts.add(a);
        }

        // We are emailing once per insert
        Test.startTest();
        insert accounts;
        Test.stopTest();
        
        List<Zyrinx_Exception__c> ex = [SELECT Type__c, Message__c, Line_Number__c, Stack_Trace__c FROM Zyrinx_Exception__c];
        for(Zyrinx_Exception__c e : ex){
            System.debug('Zyrinx_Exception__c: ' + e.Type__c + ' ' + e.Line_Number__c + ' ' + e.Message__c + ' ' + e.Stack_Trace__c);
        }

        // This hack covers dev orgs without ability to send emails
        // Of course, emails are never actually sent from Tests, but iin orgs
        // with email enabled, an email invocation limit is incremented so we
        // test that first
        Boolean emailEnabled = true;
        List<Zyrinx_Exception__c> postSendExceptions = [SELECT Id,Message__c from Zyrinx_Exception__c];
        for(Zyrinx_Exception__c e : postSendExceptions){
            if(e.Message__c.contains('Single email is not enabled')){
                emailEnabled = false;
                break;
            }
        }
        Assert.areEqual(true, (ZyrinxTriggerArchitecture.emailInvocations == 1 || emailEnabled == false));
    }

    private static testmethod void testEmailArchitectureTestAsyncBulk(){

        if(Label.TriggerBlockZyrinx == 'true') return; // This test can only work if Zyrinx is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'ZyrinxTriggerArchitectureAsyncTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_After__c = 'ZyrinxTriggerArchitectureAsyncTest';

        ZyrinxTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<50; x++){
            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            a.OwnerId = UserInfo.getUserId();
            accounts.add(a);
        }

        // We are emailing once per insert
        Test.startTest();
        insert accounts;
        Test.stopTest();
        
        List<Zyrinx_Exception__c> ex = [SELECT Type__c, Message__c, Line_Number__c, Stack_Trace__c FROM Zyrinx_Exception__c];
        for(Zyrinx_Exception__c e : ex){
            System.debug('Zyrinx_Exception__c: ' + e.Type__c + ' ' + e.Line_Number__c + ' ' + e.Message__c + ' ' + e.Stack_Trace__c);
        }

        // This hack covers dev orgs without ability to send emails
        // Of course, emails are never actually sent from Tests, but iin orgs
        // with email enabled, an email invocation limit is incremented so we
        // test that first
        Boolean emailEnabled = true;
        List<Zyrinx_Exception__c> postSendExceptions = [SELECT Id,Message__c from Zyrinx_Exception__c];
        for(Zyrinx_Exception__c e : postSendExceptions){
            if(e.Message__c.contains('Single email is not enabled')){
                emailEnabled = false;
                break;
            }
        }
        Assert.areEqual(true, (ZyrinxTriggerArchitecture.emailInvocations == 1 || emailEnabled == false));
    }
}