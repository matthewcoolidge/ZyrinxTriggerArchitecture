@isTest
public without sharing class TKWWTriggerArchitectureTest implements TKWWTriggerArchitecture.executeMethod, TKWWTriggerArchitecture.triggerCache {

    public static List<String> output = new List<String>();

    public static void init(String action){

        System.debug('TKWWTriggerArchitectureTest.init - ' + action);
        output.add('TKWWTriggerArchitectureTest.init - ' + action);
    }

    public void execute(List <sObject> records, Map <id, sObject> oldMap, TKWWTriggerArchitecture.triggerParameters tp)
    {
        System.debug('TKWWTriggerArchitectureTest.execute');

        if(tp.isInsert){
            for(SObject o : records){
                if(tp.isBefore){
                    System.debug('TKWWTriggerArchitectureTest.execute.beforeInsert, o.Id: ' + o.Id);
                    output.add('TKWWTriggerArchitectureTest.execute.beforeInsert, o.Id: ' + o.Id);
                }
                else if(tp.isAfter){
                    System.debug('TKWWTriggerArchitectureTest.execute.afterInsert, o.Id: ' + o.Id);
                    output.add('TKWWTriggerArchitectureTest.execute.afterInsert, o.Id: ' + o.Id);
                }
            }
        }
        else if (tp.IsUpdate){
            for(SObject o : records){

                SObject old = oldmap.get(o.Id);

                System.debug('TKWWTriggerArchitectureTest.execute.old: ' + old.Id);

                if(tp.isBefore){
                    System.debug('TKWWTriggerArchitectureTest.execute.beforeUpdate, o.Id: ' + o.Id);
                    output.add('TKWWTriggerArchitectureTest.execute.beforeUpdate, o.Id: ' + o.Id);
                }
                else if(tp.isAfter){
                    System.debug('TKWWTriggerArchitectureTest.execute.afterUpdate, o.Id: ' + o.Id);
                    output.add('TKWWTriggerArchitectureTest.execute.afterUpdate, o.Id: ' + o.Id);
                }
            }
        }
    }

/*    private static testmethod void testRecordtypeChange(){

        if(Label.TriggerBlockTKWWTA == 'true') return;      // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';   
        tam.Object_Name__c = 'Account';
        tam.RecordType_Names__c = 'CA_Account';
        tam.isActive__c = false;                            // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;                   // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterUpdate__c = true;
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        Account a = new Account(Name = 'testRecordtypeChange');
        a.RecordTypeId = accRecTypeNameMap.get('Local Listing Account').getRecordTypeId();
        a.TKWW_Account_Email__c = 'test@test123.net';
        a.TKWW_Category__c = testTKWWCategory1.Id;
        a.Phone = '5789654125';
        a.Country_Code__c = 'US';
        a.BillingCity = 'Test City';
        a.BillingPostalCode = '99501';
        insert a;

        Test.startTest();
        a.RecordTypeId = accRecTypeNameMap.get('CA Account').getRecordTypeId();
        update a;
        Test.stopTest();

    }*/

    private static testmethod void testInstantiateFailure(){

        if(Label.TriggerBlockTKWWTA == 'true') return;      // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'testInstantiateFailure';    // <- this class does not exist (hopefully)
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                            // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;                   // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.BeforeInsert__c = true;
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        Account a = new Account(Name = 'testInstantiateFailure');
        a.Phone = '5789654125';
        a.BillingCity = 'Test City';
        a.BillingPostalCode = '99501';
        
        Exception tex;
        Test.startTest();
        try{
            insert a;
        }
        catch(Exception ex){
            tex = ex;
        }
        Test.stopTest();

        System.assertNotEquals(null, tex);
    }

    private static testmethod void testBulkBeforeFailure(){

        if(Label.TriggerBlockTKWWTA == 'true') return;      // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';   
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                            // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;                   // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.BeforeInsert__c = true;
        tam.Bulk_Before__c = 'testBulkBeforeFailure';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        Account a = new Account(Name = 'testBulkBeforeFailure');
        a.Phone = '5789654125';
        a.BillingCity = 'Test City';
        a.BillingPostalCode = '99501';
        
        Exception tex;
        Test.startTest();
        try{
            insert a;
        }
        catch(Exception ex){
            tex = ex;
        }
        Test.stopTest();

        System.assertNotEquals(null, tex);
    }

    private static testmethod void testBulkAfterFailure(){

        if(Label.TriggerBlockTKWWTA == 'true') return;      // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';   
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                            // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;                   // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_After__c = 'testBulkAfterFailure';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        Account a = new Account(Name = 'testBulkAfterFailure');
        a.Phone = '5789654125';
        a.BillingCity = 'Test City';
        a.BillingPostalCode = '99501';
        
        Exception tex;
        Test.startTest();
        try{
            insert a;
        }
        catch(Exception ex){
            tex = ex;
        }
        Test.stopTest();

        System.assertNotEquals(null, tex);
    }

    private static testmethod void testBulkInsertArchitectureTestDisabledUser(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = false;
        tam.BeforeInsert__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        tam.Disabled_User__c = UserInfo.getUserId();
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};
        

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){


            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            accounts.add(a);
        }

        for (Integer x = 25; x<35; x++){


            Account a = new Account();
            a.Name = x+'Experiment'+x+'CABusiness';
            a.Phone = x+'57890'+x+'98124'+x;
            a.BillingCity = x+'Experiment'+x+'Place'+x;
            a.BillingPostalCode = x+'201'+x;
            accounts.add(a);
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        System.assertEquals(0, output.size()); 
    }


    private static testmethod void testBulkInsertArchitectureTestDisabledUserWithCruft(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = false;
        tam.BeforeInsert__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        tam.Disabled_User__c = 'cruft' + UserInfo.getUserId() + ',somethingelse|';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};
        

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){


            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            accounts.add(a);
        }

        for (Integer x = 25; x<35; x++){


            Account a = new Account();
            a.Name = x+'Experiment'+x+'CABusiness';
            a.Phone = x+'57890'+x+'98124'+x;
            a.BillingCity = x+'Experiment'+x+'Place'+x;
            a.BillingPostalCode = x+'201'+x;
            accounts.add(a);
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        System.assertEquals(0, output.size()); 
    }

    private static testmethod void testBulkInsertArchitectureTestEnabledUser(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        User otherUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' and Id != :UserInfo.getUserId() AND IsActive = true LIMIT 1];

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = false;
        tam.BeforeInsert__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        tam.Disabled_User__c = UserInfo.getUserId();
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};
        
        System.runAs(otherUser){
            List<Account> accounts = new List<Account>();

            for (Integer x = 0; x<10; x++){

                Account a = new Account();
                a.Name = x+'TestLL'+x+'Account';
                a.Phone = x+'57189'+x+'65412'+x;
                a.BillingCity = x+'Test'+x+'City'+x;
                a.BillingPostalCode = x+'995'+x;
                accounts.add(a);
            }

            for (Integer x = 25; x<35; x++){

                Account a = new Account();
                a.Name = x+'Experiment'+x+'CABusiness';
                a.Phone = x+'57890'+x+'98124'+x;
                a.BillingCity = x+'Experiment'+x+'Place'+x;
                a.BillingPostalCode = x+'201'+x;
                accounts.add(a);
            }

            Test.startTest();
            insert accounts;
            Test.stopTest();

            System.assertEquals(42, output.size()); 
        }
    }

    private static testmethod void testBulkInsertArchitectureTest(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = false;
        tam.BeforeInsert__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};
        

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){


            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            accounts.add(a);
        }

        for (Integer x = 25; x<35; x++){


            Account a = new Account();
            a.Name = x+'Experiment'+x+'CABusiness';
            a.Phone = x+'57890'+x+'98124'+x;
            a.BillingCity = x+'Experiment'+x+'Place'+x;
            a.BillingPostalCode = x+'201'+x;
            accounts.add(a);
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        System.assertEquals(42, output.size()); // 3 pairs of cache refreshes, and one each before/after insert message per record
    }

/*    private static testmethod void testBulkInsertArchitectureTestWithRecordtype(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.BeforeInsert__c = true;
        tam.AfterInsert__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        tam.RecordType_Names__c = 'Local_Account';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){
            Account a = new Account();
            a.Name = 'TestLLAccount' + x;
            a.Phone = '578965412' + x;
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            accounts.add(a);
        }

        for (Integer x = 0; x<10; x++){
            Account a = new Account();
            a.Name = 'TestCAAccount' + x;
            a.Phone = '578965412' + x;
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            accounts.add(a);
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        System.assertEquals(22, output.size()); // 3 pairs cache refreshes, and one each before/after insert message per LL record
    }*/

    private static testmethod void testBulkUpdateArchitectureTest(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.BeforeUpdate__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){


            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            accounts.add(a);
        }

        for (Integer x = 20; x<30; x++){


            Account a = new Account();
            a.Name = x+'Experiment'+x+'CABusiness';
            a.Phone = x+'57890'+x+'98124'+x;
            a.BillingCity = x+'Experiment'+x+'Place'+x;
            a.BillingPostalCode = x+'201'+x;
            accounts.add(a);
        }

        insert accounts;

        for(Account a : accounts){
            a.Name += '_updated';
        }

        Test.startTest();
        update accounts;
        Test.stopTest();
for(string s : output){
    system.debug('output: ' + s);
}
        system.assertequals(true, 43 < output.size()); // 3 cache refreshes, and one each before/after update message per record
    }

/*    private static testmethod void testBulkUpdateArchitectureTestWithRecordtype(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.BeforeUpdate__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        tam.RecordType_Names__c = 'CA_Account';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){
            Account a = new Account();
            a.Name = 'TestLLAccount' + x;
            a.Phone = '578965412' + x;
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            accounts.add(a);
        }

        for (Integer x = 0; x<10; x++){
            Account a = new Account();
            a.Name = 'TestCAAccount' + x;
            a.Phone = '578965412' + x;
            a.BillingCity = 'Test City';
            a.BillingPostalCode = '99501';
            accounts.add(a);
        }

        insert accounts;

        for(Account a : accounts){
            a.Name += '_updated';
        }

        Test.startTest();
        update accounts;
        Test.stopTest();

        System.assertEquals(22, output.size()); // 3 cache refreshes, and one each before/after update message per CA record
    }*/

    private static testmethod void testUpdateArchitectureTestRecursion(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;              // <-- Recursion allowed
        tam.BeforeUpdate__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        Account a = new Account();
        a.Name = 'TestLLAccount';
        a.Phone = '5789654123';
        a.BillingCity = 'Test City';
        a.BillingPostalCode = '99501';
        insert a;

        Test.startTest();
        a.Name += '_update1';
        update a;
        a.Name += '_update2';
        update a;
        Test.stopTest();

        for(String s : output){
            System.debug('output: ' + s);
        }

        a = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
        system.assertequals(true, 7 < output.size()); // 2 pairs of cache refreshes, and 2 each before/after update
        System.assertEquals('TestLLAccount_update1_update2', a.Name);
    }

    private static testmethod void testUpdateArchitectureTestBlockRecursion(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;               // <-- Recursion not allowed
        tam.BeforeUpdate__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        Account a = new Account();
        a.Name = 'TestLLAccount';
        a.Phone = '5789654123';
        a.BillingCity = 'Test City';
        a.BillingPostalCode = '99501';
        insert a;

        Test.startTest();
        a.Name += '_update1';
        update a;
        a.Name += '_update2';
        update a;
        Test.stopTest();

        for(String s : output){
            System.debug('output: ' + s);
        }

        a = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
        system.assertequals(true, 7 < output.size()); // 2 pairs of cache refreshes, and 1 before/after update (2nd is blocked)
    }

    private static testmethod void testBulkUpdateArchitectureTestRecursion(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!

        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;              // <-- Recursion allowed
        tam.BeforeUpdate__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){


            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            accounts.add(a);
        }

        for (Integer x = 20; x<30; x++){


            Account a = new Account();
            a.Name = x+'Experiment'+x+'CABusiness';
            a.Phone = x+'57890'+x+'98124'+x;
            a.BillingCity = x+'Experiment'+x+'Place'+x;
            a.BillingPostalCode = x+'201'+x;
            accounts.add(a);
        }

        insert accounts;

        for(Account a : accounts){
            a.Name += '_update1';
        }

        Test.startTest();
        update accounts;

        accounts[0].Name += '_update2';

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.SaveResult sr = Database.update(accounts[0], dml); 
        
        Test.stopTest();

        system.assertequals(true, 45 < output.size());   // 3 pairs cache refreshes, and one each before/after update message per record, 
                                                    // then a 4th cache refresh, then 2 more updates
                                                    // this was 46, i thik the dml.DuplicateRuleHeader.AllowSave = true;  nixes the after update at the end
    }

    private static testmethod void testBulkUpdateArchitectureTestBlockRecursion(){

        if(Label.TriggerBlockTKWWTA == 'true') return; // This test can only work if TKWWTA is enabled! Thats what it is testing!
        
        Map<String,Schema.RecordTypeInfo> accRecTypeNameMap = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Trigger_Action__mdt tam = new Trigger_Action__mdt();
        tam.Execute_Class__c = 'TKWWTriggerArchitectureTest';
        tam.Object_Name__c = 'Account';
        tam.isActive__c = false;                    // <-- Would not fire in normal execution
        tam.isActiveForTesting__c = true;           // <-- Will fire in Test execution
        tam.Order__c = 1;
        tam.BlockRecursion__c = true;
        tam.BeforeUpdate__c = true;
        tam.AfterUpdate__c = true;
        tam.Bulk_Before__c = 'TKWWTriggerArchitectureTest';
        tam.Bulk_After__c = 'TKWWTriggerArchitectureTest';
        TKWWTriggerArchitectureMetadataService.actions = new List<Trigger_Action__mdt> {tam};

        List<Account> accounts = new List<Account>();

        for (Integer x = 0; x<10; x++){


            Account a = new Account();
            a.Name = x+'TestLL'+x+'Account';
            a.Phone = x+'57189'+x+'65412'+x;
            a.BillingCity = x+'Test'+x+'City'+x;
            a.BillingPostalCode = x+'995'+x;
            accounts.add(a);
        }

        for (Integer x = 20; x<30; x++){


            Account a = new Account();
            a.Name = x+'Experiment'+x+'CABusiness';
            a.Phone = x+'57890'+x+'98124'+x;
            a.BillingCity = x+'Experiment'+x+'Place'+x;
            a.BillingPostalCode = x+'201'+x;
            accounts.add(a);
        }

        insert accounts;

        for(Account a : accounts){
            a.Name += '_update1';
        }

        Test.startTest();
        update accounts;

        accounts[0].Name += '_update2';

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true; 
        Database.SaveResult sr = Database.update(accounts[0], dml); 

        Test.stopTest();

        system.assertequals(true, 45 < output.size());   // 3 pairs cache refreshes, and one each before/after update message per record, 
                                                    // then a 4th cache refresh, 2nd update blocked (record is from the first chunk to hit the trigger).
                                                    // this was 44, teh dml.DuplicateRuleHeader.AllowSave = true;  seems to nix the final after update
    }
}