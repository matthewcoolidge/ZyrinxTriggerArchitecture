global without sharing class ZyrinxTriggerArchitecture {

    ////////////////////////////////////////////
    // Use this in Test Classes to determine if Email Sends have occured in Async post-
    // processing. Normally you'd check that limit within Test.StartTest() -> Test.StopTest(),
    // but doing Async, you cannot because you must use Test.StopTest to finalize all 
    // Asynchronous operations. So this variable is available in tests
    ////////////////////////////////////////////
    @TestVisible public static Integer emailInvocations=0;

    ////////////////////////////////////////////
    // In this version, we have certain cases where we want to execute Synchronously even
    // if the Implementing class calls for Async post-execute DML.
    // Mainly, we want UI operations to use Synchronous DML operations.
    // NOTE that this is initially NULL, so it can be set on the first pass / top level
    // of executeAllMethods, and that value will be used for the entire Transaction
    ////////////////////////////////////////////
    @TestVisible public static Boolean allowAsynchronousProcessing;

    ////////////////////////////////////////////
    // The maximum allowed raw (unfiltered by RecordType and/or Recursion blocking) 
    // number of records for which we will force Synchronous post-processingn DML.
    // This defaults to 1 and is set via the Default instance of Trigger_Settings_Zyrinx__mdt
    ////////////////////////////////////////////
    private static final Integer SYNCRONOUS_RECORD_LIMIT;

    ////////////////////////////////////////////
    // Exception if needed
    ////////////////////////////////////////////
    public virtual class ZyrinxTriggerArchitectureException extends Exception{}

    ////////////////////////////////////////////
    // Interface to be implemented by target Classes
    ////////////////////////////////////////////
    global interface executeMethod
    {
        void execute(List <sObject> records, Map <id, sObject> oldMap, ZyrinxTriggerArchitecture.triggerParameters tp);
    }

    ////////////////////////////////////////////
    // Interface to be implemented by Before/After cache Classes
    ////////////////////////////////////////////
    global interface triggerCache
    { 
        void init(String context);
    }

    ////////////////////////////////////////////
    // Superclass to be extended by target Classes to perform post-execute work Asynchronously.
    // This is a fully functional default implementation, but one could extend this and
    // override the postExecute method, as well as the DML list methods
    ////////////////////////////////////////////
    global virtual class asyncProcessing
    {
        List<SObject> insertObjectsList = new List<SObject>();
        List<SObject> updateObjectsList = new List<SObject>();
        List<SObject> deleteObjectsList = new List<SObject>();
        List<Messaging.SingleEmailMessage> mailObjectsList = new List<Messaging.SingleEmailMessage>();

        global virtual void insertObject(SObject obj){
            insertObjectsList.add(obj);
        }

        global virtual void insertObjects(List<SObject> objs){
            insertObjectsList.addAll(objs);
        }

        global virtual void updateObject(SObject obj){
            updateObjectsList.add(obj);
        }

        global virtual void updateObjects(List<SObject> objs){
            updateObjectsList.addAll(objs);
        }

        global virtual void deleteObject(SObject obj){
            deleteObjectsList.add(obj);
        }

        global virtual void deleteObjects(List<SObject> objs){
            deleteObjectsList.addAll(objs);
        }

        global virtual void mailObject(Messaging.SingleEmailMessage obj){
            mailObjectsList.add(obj);
        }

        global virtual void mailObjects(List<Messaging.SingleEmailMessage> objs){
            mailObjectsList.addAll(objs);
        }

        ////////////////////////////////////////
        // Method called by the Zyrinx platform after .execute on any executeMethod implementer
        // which also extends asyncProcessing
        ////////////////////////////////////////
        global virtual void postExecute(ZyrinxTriggerArchitecture.triggerParameters tp, Boolean debugMode){

            Boolean debug = debugMode;
            String executeClassName = String.valueOf(this).split(':')[0];
            Integer getQueueableJobs = Limits.getQueueableJobs();
            Integer getLimitQueueableJobs = Limits.getLimitQueueableJobs();
            Boolean atLimit = getQueueableJobs >= getLimitQueueableJobs;
            System.debug(executeClassName + '.postExecute, ' + getQueueableJobs + '/' + getLimitQueueableJobs + ' jobs' + ((atLimit) ? ' AT LIMIT' : ''));

            List<Zyrinx_Exception__c> exceptionList = new List<Zyrinx_Exception__c>();

            if(debug){
                System.debug('insertObjects: ' + insertObjectsList.size());
                System.debug('updateObjects: ' + updateObjectsList.size());
                System.debug('deleteObjects: ' + deleteObjectsList.size());
                System.debug('mailObjects: ' + mailObjectsList.size());
            }

            ////////////////////////////////////////
            // If any SObjects have been added to insertObjects, if we have a Queuable available (Limit is 50),
            // create a AsyncProcessorInsert with those SObjects and add to the queue. If we are at limit, 
            // revert to a Synchronous insert
            ////////////////////////////////////////
            if(insertObjectsList.size() > 0){
            
                ////////////////////////////////////////
                // This groups like SObject types together; you can DML up to 10 different types
                ////////////////////////////////////////
                insertObjectsList.sort();

                ////////////////////////////////////////
                // If Queueable Limit is available and Asynch is not blocked (because of an implied UI operation),
                // enqueue this job. Otherwise, execute the DML synchronously
                ////////////////////////////////////////
                if(!atLimit && ZyrinxTriggerArchitecture.allowAsynchronousProcessing){
                    System.enqueueJob(new AsyncProcessorInsert(insertObjectsList, executeClassName));
                }
                else{
                    if(debug && atLimit) {System.debug(executeClassName + '.postExecute AT LIMIT, reverting to synchronous INSERT');}
                    else if(debug) {System.debug(executeClassName + '.postExecute allowAsynchronousProcessing is FALSE, reverting to synchronous INSERT');}
                    List<Database.SaveResult> saveResultList = Database.insert(insertObjectsList, false);
                    exceptionList.addAll(ExceptionUtility.consumeException(saveResultList, executeClassName + '.postExecute Synchronous process in ' + executeClassName));
                }
            }

            ////////////////////////////////////////
            // If any SObjects have been added to updateObjects, if we have a Queuable available (Limit is 50),
            // create a AsyncProcessorUpdate with those SObjects and add to the queue. If we are at limit, 
            // revert to a Synchronous update
            ////////////////////////////////////////
            if(updateObjectsList.size() > 0){
            
                ////////////////////////////////////////
                // De-duplication of any SObjects placed into the update List
                ////////////////////////////////////////
                Set<SObject> dedupeSet = new Set<sobject>();
                List<SObject> dedupeResult = new List<sobject>();
                dedupeSet.addAll(updateObjectsList);
                dedupeResult.addAll(dedupeSet);

                ////////////////////////////////////////
                // This groups like SObject types together; you can DML up to 10 different types
                ////////////////////////////////////////
                dedupeResult.sort();

                ////////////////////////////////////////
                // If Queueable Limit is available and Asynch is not blocked (because of an implied UI operation),
                // enqueue this job. Otherwise, execute the DML synchronously
                ////////////////////////////////////////
                if(!atLimit && ZyrinxTriggerArchitecture.allowAsynchronousProcessing){
                    System.enqueueJob(new AsyncProcessorUpdate(dedupeResult, executeClassName));
                }
                else{
                    if(debug && atLimit) {System.debug(executeClassName + '.postExecute AT LIMIT, reverting to synchronous UPDATE');}
                    else if(debug) {System.debug(executeClassName + '.postExecute allowAsynchronousProcessing is FALSE, reverting to synchronous UPDATE');}
                    List<Database.SaveResult> saveResultList = Database.update(dedupeResult, false);
                    exceptionList.addAll(ExceptionUtility.consumeException(saveResultList, executeClassName + '.postExecute Synchronous process in ' + executeClassName));
                }
            }

            ////////////////////////////////////////
            // If any SObjects have been added to deleteObjects, if we have a Queuable available (Limit is 50),
            // create a AsyncProcessorDelete with those SObjects and add to the queue. If we are at limit, 
            // revert to a Synchronous delete
            ////////////////////////////////////////
            if(deleteObjectsList.size() > 0){
            
                ////////////////////////////////////////
                // De-duplication of any SObjects placed into the delete List
                ////////////////////////////////////////
                Set<SObject> dedupeSet = new Set<sobject>();
                List<SObject> dedupeResult = new List<sobject>();
                dedupeSet.addAll(deleteObjectsList);
                dedupeResult.addAll(dedupeSet);

                ////////////////////////////////////////
                // This groups like SObject types together; you can DML up to 10 different types
                ////////////////////////////////////////
                dedupeResult.sort();

                ////////////////////////////////////////
                // If Queueable Limit is available and Asynch is not blocked (because of an implied UI operation),
                // enqueue this job. Otherwise, execute the DML synchronously
                ////////////////////////////////////////
                if(!atLimit && ZyrinxTriggerArchitecture.allowAsynchronousProcessing){
                    System.enqueueJob(new AsyncProcessorDelete(dedupeResult, executeClassName));
                }
                else{
                    if(debug && atLimit) {System.debug(executeClassName + '.postExecute AT LIMIT, reverting to synchronous DELETE');}
                    else if(debug) {System.debug(executeClassName + '.postExecute allowAsynchronousProcessing is FALSE, reverting to synchronous DELETE');}
                    List<Database.DeleteResult> saveResultList = Database.delete(dedupeResult, false);
                    exceptionList.addAll(ExceptionUtility.consumeException(saveResultList, executeClassName + '.postExecute Synchronous process in ' + executeClassName));
                }
            }

            ////////////////////////////////////////
            // If any Messaging.SingleEmailMessages have been added to mailObjects, if we have a Queuable available (Limit is 50),
            // create a AsyncProcessorMail with those Messaging.SingleEmailMessages and add to the queue. If we are at limit, 
            // revert to a Synchronous Messaging.sendEmail
            ////////////////////////////////////////
            if(mailObjectsList.size() > 0){

                if(!atLimit){
                    System.enqueueJob(new AsyncProcessorMail(mailObjectsList, executeClassName));
                }
                else{
                    List<Messaging.SendEmailResult> saveResultList = Messaging.sendEmail(mailObjectsList, false);
                    if(Test.isRunningTest()){
                        ZyrinxTriggerArchitecture.emailInvocations += Limits.getEmailInvocations();
                    }
                    List<Zyrinx_Exception__c> sendExceptions = ExceptionUtility.consumeException(saveResultList, executeClassName + '.postExecute AT LIMIT in ' + executeClassName);
                    exceptionList.addAll(sendExceptions);
                } 
            }
            
            ////////////////////////////////////////
            // If any processing reverted to Synchronous due to Limits, and Exceptions occured, save them
            ////////////////////////////////////////
            if(exceptionList.size()>0){
                insert exceptionList;
            }
        }
    }

    ////////////////////////////////////////
    // Default queueable INSERT implementor
    ////////////////////////////////////////
    global class AsyncProcessorInsert implements Queueable{

        List<Zyrinx_Exception__c> exceptionList = new List<Zyrinx_Exception__c>();

        String caller = 'AsyncProcessorInsert';
        List<SObject> records;

        global AsyncProcessorInsert(List<SObject> recs){
            records = recs;
        }

        global AsyncProcessorInsert(List<SObject> recs, String call){
            caller = call;
            records = recs;
        }

        public void execute(QueueableContext context){

            System.debug(caller + '.execute: ' + records.size() + ' records to be inserted');

            List<Database.SaveResult> saveResultList = Database.insert(records, false);
            exceptionList.addAll(ExceptionUtility.consumeException(saveResultList, 'AsyncProcessorInsert in ' + caller));

            if(exceptionList.size()>0){
                insert exceptionList;
            }
        }
    }

    ////////////////////////////////////////
    // Default queueable UPDATE implementor
    ////////////////////////////////////////
    global class AsyncProcessorUpdate implements Queueable{

        List<Zyrinx_Exception__c> exceptionList = new List<Zyrinx_Exception__c>();

        String caller = 'AsyncProcessorUpdate';
        List<SObject> records;

        global AsyncProcessorUpdate(List<SObject> recs){
            records = recs;
        }

        global AsyncProcessorUpdate(List<SObject> recs, String call){
            caller = call;
            records = recs;
        }

        public void execute(QueueableContext context){

            System.debug(caller + '.execute: ' + records.size() + ' records to be updated');

            List<Database.SaveResult> saveResultList = Database.update(records, false);
            exceptionList.addAll(ExceptionUtility.consumeException(saveResultList, 'AsyncProcessorUpdate in ' + caller));

            if(exceptionList.size()>0){
                insert exceptionList;
            }
        }
    }

    ////////////////////////////////////////
    // Default queueable DELETE implementor
    ////////////////////////////////////////
    global class AsyncProcessorDelete implements Queueable{

        List<Zyrinx_Exception__c> exceptionList = new List<Zyrinx_Exception__c>();

        String caller = 'AsyncProcessorDelete';
        List<SObject> records;

        global AsyncProcessorDelete(List<SObject> recs){
            records = recs;
        }

        global AsyncProcessorDelete(List<SObject> recs, String call){
            caller = call;
            records = recs;
        }

        public void execute(QueueableContext context){

            System.debug(caller + '.execute: ' + records.size() + ' records to be deleted');

            List<Database.DeleteResult> saveResultList = Database.delete(records, false);
            exceptionList.addAll(ExceptionUtility.consumeException(saveResultList, 'AsyncProcessorDelete in ' + caller));

            if(exceptionList.size()>0){
                insert exceptionList;
            }
        }
    }

    ////////////////////////////////////////
    // Default queueable Messaging.sendEmail implementor
    ////////////////////////////////////////
    public class AsyncProcessorMail implements Queueable, Database.AllowsCallouts{

        List<Zyrinx_Exception__c> exceptionList = new List<Zyrinx_Exception__c>();

        String caller = 'AsyncProcessorMail';

        ////////////////////////////////////////////
        // Messaging.SingleEmailMessage is NOT serializable, so we can only pass them to 
        // execute via a wrapper class (EmailUtility.ZyrinxEmailWrapper). We then rebuild the 
        // actual Messaging.SingleEmailMessages in execute before sending
        ////////////////////////////////////////////
        List<EmailUtility.ZyrinxEmailWrapper> records = new List<EmailUtility.ZyrinxEmailWrapper>();

        public AsyncProcessorMail(List<Messaging.SingleEmailMessage> recs){
            for(Messaging.SingleEmailMessage message: recs){
                records.add(new EmailUtility.ZyrinxEmailWrapper(message));
            }
        }

        public AsyncProcessorMail(List<Messaging.SingleEmailMessage> recs, String call){
            caller = call;
            for(Messaging.SingleEmailMessage message: recs){
                records.add(new EmailUtility.ZyrinxEmailWrapper(message));
            }
        }

        public void execute(QueueableContext context){

            System.debug(caller + '.execute: ' + records.size() + ' Messaging.SingleEmailMessages to be sent');

            ////////////////////////////////////////////
            // Messaging.SingleEmailMessage is NOT serializable, so we can only pass them to 
            // execute via a wrapper class (EmailUtility.ZyrinxEmailWrapper). We then rebuild the 
            // actual Messaging.SingleEmailMessages here before sending
            ////////////////////////////////////////////
            List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
            for(EmailUtility.ZyrinxEmailWrapper wrapper : records){
                messages.add(wrapper.generateSingleEmailMessage());
            }
            List<Messaging.SendEmailResult> saveResultList = Messaging.sendEmail(messages, false);

            if(Test.isRunningTest()){
                ZyrinxTriggerArchitecture.emailInvocations += Limits.getEmailInvocations();
            }

            List<Zyrinx_Exception__c> sendExceptions = ExceptionUtility.consumeException(saveResultList,'AsyncProcessorMail in ' + caller);
            exceptionList.addAll(sendExceptions);

            if(exceptionList.size()>0){
                insert exceptionList;
            }
        }
    }

    ////////////////////////////////////////////
    // Maps and map controllers for current execution context
    ////////////////////////////////////////////
    public static Map <string, List <Trigger_Action__mdt>> triggerActionMap;
    public static boolean alreadyBuiltActionMap = false;
    private static String currentAction;

    // Recursion check is now per-record; these are the records processed so far
    private static Map<String, Set<Id>> recordsAlreadyProcessed = new Map<String, Set<Id>>();

    // Use ZyrinxTriggerArchitectureSetting__c to set Expanded_Debugging__c to true for debug mode
    private static Boolean debug = false;

    ////////////////////////////////////////////
    // static ctor for one-time initializations
    ////////////////////////////////////////////
    static{

        // Use expanded Debugging in ZyrinxTriggerArchitectureSetting__c for ... Debugging!
        if(ZyrinxTriggerArchitectureSetting__c.getInstance(Userinfo.getUserId()).Expanded_Debugging__c){
            debug = true;
        }

        // Gets the triggerActionMap, either from CMDT or from overrides sent to the ZyrinxTriggerArchitectureMetadataService via tests
        getTriggerActionData();

        // Get the maximum number of records (default: 1) which will force Synchronous DML in post processing
        SYNCRONOUS_RECORD_LIMIT  = ZyrinxTriggerArchitectureMetadataService.getSynchronousRecordLimit();
    }

    ////////////////////////////////////////////
    // Generic method to be placed in triggers to run all enabled Trigger Actions
     ////////////////////////////////////////////
    global static void executeAllMethods(){

        System.debug('ZyrinxTriggerArchitectureSetting__c.getInstance(Userinfo.getUserId()).Block_Triggers__c: ' + ZyrinxTriggerArchitectureSetting__c.getInstance(Userinfo.getUserId()).Block_Triggers__c);
        // mcoolidge 2020-08-12 SFDEV-1094
        // If this User has Triggers blocked, do not execute.
        if(ZyrinxTriggerArchitectureSetting__c.getInstance(Userinfo.getUserId()).Block_Triggers__c){
            if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods - blocking ctor for: ' + Userinfo.getUserName());
            return;
        }

        // Gets the old and new data and the trigger context ( before/after, insert/update/delete/undelete)
        TriggerParameters tp = getTriggerParams();

        // Create the map entry for this TriggerAction to save its processed records
        if(!recordsAlreadyProcessed.containsKey(tp.defaultName)){
            recordsAlreadyProcessed.put(tp.defaultName, new Set<Id>());
        }

        // Determine if we want to allow Implementors to do DML operations asynchronously.
        // As detailed above, mainly we want to prevent UI operations from Async DML.
        // This should only ever be set for the top-level triggered object, per Transaction
        if(allowAsynchronousProcessing == null){
            Integer recordCount = trigger.isDelete ? trigger.old.size() : trigger.new.size();
            if(recordCount > SYNCRONOUS_RECORD_LIMIT ||
                System.isBatch() ||
                System.isScheduled())
            {
                allowAsynchronousProcessing = true;
            }
            else{
                allowAsynchronousProcessing = false;
            }
        }

        if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods');
        if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.tp.defaultName: ' + tp.defaultName);
        if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.triggerActionMap: ' + triggerActionMap);
        if (debug) System.debug('ZyrinxTriggerArchitecture.allowAsynchronousProcessing: ' + allowAsynchronousProcessing);

        if(triggerActionMap.containsKey(tp.defaultName.toLowerCase())){ // this will look like "accountafterinsert", for example

            // list of TriggerActions for this context, ex. "accountafterinsert"
            List <Trigger_Action__mdt> actionData = triggerActionMap.get(tp.defaultName.toLowerCase()); 
            if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.actionData: ' + actionData);

            // sorting variables
            List<double> sortList = new List<Double>();
            Map <double, Trigger_Action__mdt> executeMap = new Map <double, Trigger_Action__mdt>();
            Integer defaultSort = 1000; // Items with no sort specified go to the end

            for(Trigger_Action__mdt ta : actionData){

                // Lists of CMDTs have some interesting byref behavior, notably the Order__c carries over from 
                // the last one to the next one in this loop. So we use a clone of each.
                Trigger_Action__mdt g = ta.clone();

                // If no Order__c is supplies, use and increment the default
                if(g.Order__c == null){
                    g.Order__c = defaultSort;
                    defaultSort += 1;
                }

                // If a dupe order is supplied, shift the dupe up slightly in Order so we don't overwrite the existing key
                else if (executeMap.containsKey(g.Order__c)){
                    while(executeMap.containsKey(g.Order__c)){
                        g.Order__c -= 0.001;
                    }
                }

                sortList.add(g.order__c);
                executeMap.put(g.order__c, g);
            }
            //make sure we have a list sorted by the order of execution 
            sortList.Sort();
            if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.sortList: ' + sortList);
            if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.executeMap: ' + executeMap);

            // List of Cache classes that have been instantiated for the current context. This allows Trigger Actions
            // to have different Bulk Before/After classes in the same context if desired.
            List<String> cacheClassesInstantiated = new List<String>();

            // Get available RecordType Developer Names for this SObject type, for filtering
            Map<String,Id> recordTypesForObject = getRecordTypeDevNamesForType(tp.triggerObject);
            if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.recordTypesForObject: ' + recordTypesForObject);

            // cache of new/old records by RecordType
            Map<String, List<SObject>> filteredRecordsCache = new Map<String, List<SObject>>();
            Map<String, Map<Id, sObject>> filteredOldMapCache = new Map<String, Map<Id, sObject>>();

            for(double r : sortList){   

                Trigger_Action__mdt thisTriggerAction = executeMap.get(r);
                if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.thisTriggerAction: ' + thisTriggerAction);

                // make sure each Trigger Action, cmdt is Active or Test Active, depending on context
                if((Test.isRunningTest() == false && thisTriggerAction.isActive__c == true)
                   || (Test.isRunningTest() == true && thisTriggerAction.isActiveForTesting__c == true)){

                    // mcoolidge 2023-05-05 https://theknotww.atlassian.net/browse/QTC-5707
                    if(thisTriggerAction.Disabled_User__c == null || !thisTriggerAction.Disabled_User__c.contains(Userinfo.getUserId())){
                
                        // if this Trigger Action contains a Bulk Before or Bulk After, instantiate the appropriate one
                        // NOTE that:
                        //  1) Bulk Before and Bulk After classes MUST implement ZyrinxTriggerArchitecture.triggerCache
                        //  2) Bulk Before and Bulk After classes MUST only do work inside their init method
                        // The end result is that each Bulk class only gets instantiated once per action, before the  
                        // first Trigger Action which references it. This resets per slice, as caches will need to be
                        // refreshed for each slice of records
                        if(thisTriggerAction.Bulk_Before__c != null && ZyrinxTriggerArchitecture.isContextBefore(tp)==true){

                            // Refresh our relevant cache ONLY when:
                            //  1) the action changes (i.e., NULL to insert, insert to update) OR
                            //  2) this PARTICULAR cache class has not been instantiated in this context
                            // This allows Trigger Actions in the same context to use different cache classes
                            if(tp.action != currentAction || // tp.defaultName.toLowerCase()
                                cacheClassesInstantiated.contains(thisTriggerAction.Bulk_Before__c) == false)
                            {
                                instantiateBulkClass(thisTriggerAction.Bulk_Before__c, tp.action);
                                cacheClassesInstantiated.add(thisTriggerAction.Bulk_Before__c);
                            }
                        }
                        else if(thisTriggerAction.Bulk_After__c != null && ZyrinxTriggerArchitecture.isContextBefore(tp)==false){

                            // Refresh our relevant cache ONLY when:
                            //  1) the action changes (i.e., NULL to insert, insert to update) OR
                            //  2) this PARTICULAR cache class has not been instantiated in this context
                            // This allows Trigger Actions in the same context to use different cache classes
                            if(tp.action != currentAction || // tp.defaultName.toLowerCase()
                                cacheClassesInstantiated.contains(thisTriggerAction.Bulk_After__c) == false)
                            {
                                instantiateBulkClass(thisTriggerAction.Bulk_After__c, tp.action);
                                cacheClassesInstantiated.add(thisTriggerAction.Bulk_After__c);
                            }
                        }

                        // store which action we just loaded the cache for
                        currentAction = tp.action;

                        // Prefilter records by RecordType (if requested in this TriggerAction)
                        List<SObject> filteredRecords = new List<SObject>();
                        Map<Id, sObject> filteredOldMap = new Map<Id, sObject>();

                        // if this Trigger Action contains a RecordType filter, pre-process the records and oldMap here.
                        // We do the RecordType filter first because we can and do cache the results. We cannot obviously
                        // cache the recursion check as it will change in every slice of records
                        if (thisTriggerAction.RecordType_Names__c != null){
                            
                            // This SObject has one or more recordTypes...
                            if(recordTypesForObject.size() > 0){

                                for(String thisRecordType : thisTriggerAction.RecordType_Names__c.Split(',')){

                                    // Cache the records filtered by RecordType, if other Trigger actions need the same filter (which is common)
                                    if(filteredRecordsCache.containsKey(thisRecordType)==false){
                                        List<SObject> tempFilteredRecords = filterRecordsbyRecordTypes(thisRecordType, recordTypesForObject, tp.records);
                                        filteredRecordsCache.put(thisRecordType, tempFilteredRecords);
                                    }
                                    filteredRecords.addAll(filteredRecordsCache.get(thisRecordType));

                                    // We do not filter the oldmap by Recordtype (see SFDEV-2127)
                                    if(tp.oldMap != null){
                                        filteredOldMap.putAll(tp.oldMap);
                                    }
                                }
                            }
                            else{
                                // Trigger Action called for record Type filtering but the SObject does not support it
                                filteredRecords = tp.records;
                                filteredOldMap = tp.oldMap;
                            }
                        }
                        else{
                            // Trigger Action does not have a RecordType filter
                            filteredRecords = tp.records;
                            filteredOldMap = tp.oldMap;
                        }

                        // These are the filtered records we'll use for this Trigger Action (Recursion filtering)
                        List<SObject> filteredRecordsFinal = new List<SObject>();
                        Map<Id, sObject> filteredOldMapFinal = new Map<Id, sObject>();

                        // If Recursion blocking for this action, filter off any Records processed in the Context
                        // Recursion checking moved from per method to per record to support the 200 record
                        // slices that the runtime passes to Triggers all in the same execution context,
                        // if more than 200 records are in the Batch.
                        if(thisTriggerAction.BlockRecursion__c == true){ 
                            filteredRecordsFinal = filterRecordsbyAlreadyProcessed(tp, recordsAlreadyProcessed, filteredRecords);
                            if(tp.oldMap!=null){
                                filteredOldMapFinal = new Map<Id, sObject>(filterRecordsbyAlreadyProcessed(tp, recordsAlreadyProcessed, filteredOldMap.values()));
                            }
                        }
                        else{
                            filteredRecordsFinal = filteredRecords;
                            filteredOldMapFinal = filteredOldMap;
                        }

                        // execute the "execute" method in the class thisTriggerAction.Execute_Class__c with the data in this context
                        // NEW: Do NOT executeCode if the4re are no records to operate on, either due to RecordType filtering
                        // or recursion blocking
                        if(filteredRecordsFinal.size() > 0){
                            executeCode(thisTriggerAction.Execute_Class__c, filteredRecordsFinal, (filteredOldMapFinal == null || filteredOldMapFinal.values().size() == 0) ? null : filteredOldMapFinal, tp, true);
                        }
                    }
                    else{
                        // mcoolidge 2023-05-05 https://theknotww.atlassian.net/browse/QTC-5707
                        System.debug('ZyrinxTriggerArchitecture.executeAllMethods.' + thisTriggerAction.Execute_Class__c + ' DISABLED FOR USER: ' + Userinfo.getName() + ' (' + UserInfo.getUserId() + ')');
                    }
                }
                else{
                    // Inactive Trigger Action cmdt for context (test or non-test)
                    continue;
                }
            }

            // Now add these records to our "Already Processed" Map, after we executed all appropriate TriggerActions on this set
            if(Trigger.newMap != null){
                recordsAlreadyProcessed.get(tp.defaultName).addAll(Trigger.newMap.keyset());
            }
        }
    }

    ////////////////////////////////////////////
    // Internal methods to invoke execute methods in specific executeMethod-implementing classes
    ////////////////////////////////////////////
/*     private static void executeCode(string executeClassName, List <sObject> records, Map <id, sObject> oldMap){  
        executeCode(executeClassName, records, oldMap, null, false);  
    }
    
    private static void executeCode(string executeClassName, List <sObject> records, Map <id, sObject> oldMap, triggerParameters tp){ 
        executeCode(executeClassName, records, oldMap, tp, false);     
    } */

    private static void executeCode(string executeClassName, List <sObject> records, Map <id, sObject> oldMap, triggerParameters tp, boolean executeAll){

        if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.executeCode');
        if (debug) System.debug('ZyrinxTriggerArchitecture.executeAllMethods.executeCode.executeClassName: ' + executeClassName); 

        // Active and Recursion blocked checks have already been made
        executeMethodWrapper(executeClassName, records, oldMap, tp);
    }

    ////////////////////////////////////////////
    // Internals to invoke execute methods in executeMethod-implementing classes
    ////////////////////////////////////////////
    private static void executeMethodWrapper(string executeClassName, List <sObject> records, Map <id, sObject> oldMap, ZyrinxTriggerArchitecture.triggerParameters tp)
    {   
        if (debug) System.debug('ZyrinxTriggerArchitecture.executeMethodWrapper');

        List<Zyrinx_Exception__c> exceptionList = new List<Zyrinx_Exception__c>();

        Type t;
        ZyrinxTriggerArchitecture.executeMethod em;

        // Make sure the supplied executeClassName exists and can be instantiated
        try{
            t = Type.forName(executeClassName);
            em =  (ZyrinxTriggerArchitecture.executeMethod) t.newInstance();
        }
        catch (Exception tex){
            if(Test.isRunningTest() || debug){
                System.debug('ZyrinxTriggerArchitecture unable to instantiate: ' + executeClassName);
                ExceptionUtility.printException(tex);
                throw tex;
            }
            ExceptionUtility.consumeException(tex, 'ZyrinxTriggerArchitecture unable to instantiate: ' + executeClassName, true);
        }

        // Make sure the supplied executeClassName can be executed. Unless they catch their own exceptions, runtime
        // errors will bubble to here
        try{
            System.debug('executeMethodWrapper (filtered): ' + executeClassName + '.execute (' + records.size() + ') records');
            em.execute(records, oldMap, tp);
            System.debug('executeMethodWrapper (filtered): ' + executeClassName + '.execute complete');
        }
        catch (Exception eex){
            if(Test.isRunningTest() || debug){
                System.debug('ZyrinxTriggerArchitecture unable to execute: ' + executeClassName);
                ExceptionUtility.printException(eex);
                throw eex;
            }
            ExceptionUtility.consumeException(eex, 'ZyrinxTriggerArchitecture unable to execute: ' + executeClassName, true);
        }

        // If this implementor extends ZyrinxTriggerArchitecture.asyncProcessing, attempt to call its
        // .postExecute method which will attempt DML operations for insert, update, delete, 
        // and also Messaging.sendEmail for any objects added to those collections by the implementor 
        if(em instanceof ZyrinxTriggerArchitecture.asyncProcessing){
            try{
                ZyrinxTriggerArchitecture.asyncProcessing ap = (ZyrinxTriggerArchitecture.asyncProcessing)em;
                System.debug('executeMethodWrapper: ' + executeClassName + '.postExecute');
                ap.postExecute(tp, debug);
                System.debug('executeMethodWrapper: ' + executeClassName + '.postExecute complete');
            }
            catch(Exception aex){
                if(Test.isRunningTest() || debug){
                    System.debug('ZyrinxTriggerArchitecture unable to Async Post Process: ' + executeClassName);
                    ExceptionUtility.printException(aex);
                    throw aex;
                }
                ExceptionUtility.consumeException(aex, 'ZyrinxTriggerArchitecture unable to Async Post Process: ' + executeClassName, true);
            }
        }
    }

    ////////////////////////////////////////////
    // Internals to instantiate Bulk Before and Bulk After classes
    ////////////////////////////////////////////
    private static void instantiateBulkClass(string bulkClassName, string action)
    {   
        if (debug) System.debug('ZyrinxTriggerArchitecture.instantiateBulkClass');

        Type t = Type.forName(bulkClassName);
        ZyrinxTriggerArchitecture.triggerCache tb =  (ZyrinxTriggerArchitecture.triggerCache) t.newInstance();
        tb.init(action);

    }

    ////////////////////////////////////////////
    // Internals to build the map of trigger class/actions to lists to triggeraction CMDTs
    // NOTE that you can, in a Test Class, set ZyrinxTriggerArchitectureMetadataService.actions directly
    ////////////////////////////////////////////    
    private static void getTriggerActionData()
    {
        if(alreadyBuiltActionMap == true){
            return;
        }
        alreadyBuiltActionMap = true;
        
        triggerActionMap = new Map <string, List <Trigger_Action__mdt>>();
        
        List<Trigger_Action__mdt> actions = ZyrinxTriggerArchitectureMetadataService.getTriggerActions();
        for(Trigger_Action__mdt g : actions){
            getDefaultNameFromSetting(g);       
        }
        if (debug) System.debug('getTriggerActionData.triggerActionMap: ' + triggerActionMap);
    }
    
    ////////////////////////////////////////////
    // Internals to check if a specific action for example, 'accountafterinsert', is active for the execute-implementing class and context (test/non-test)
    // NOTE: this is Deprecated
    ////////////////////////////////////////////    
/*     private static boolean isActive (string action, string executeClassName){

        if (debug) System.debug('ZyrinxTriggerArchitecture.isActive');   
        if (debug) System.debug('ZyrinxTriggerArchitecture.isActive.action: ' + action);  
        if (debug) System.debug('ZyrinxTriggerArchitecture.isActive.executeClassName: ' + executeClassName);  

        action = action.toLowerCase();
        getTriggerActionData();
        
        if(triggerActionMap == null){
            return false;
        }
        if (debug) System.debug('ZyrinxTriggerArchitecture.isActive.triggerActionMap: ' + triggerActionMap + ' (' + triggerActionMap.containsKey(action) + ')');

        if(Test.IsRunningTest() == false && triggerActionMap.containsKey(action)){
            for (Trigger_Action__mdt ta : triggerActionMap.get(action)){
                if(ta.Execute_Class__c == executeClassName){
                    return ta.isActive__c;
                }
            }
        }
        else if(Test.IsRunningTest() == true && triggerActionMap.containsKey(action)){
            for (Trigger_Action__mdt ta : triggerActionMap.get(action)){
                if(ta.Execute_Class__c == executeClassName){
                    return ta.isActiveForTesting__c;
                }
            }
        }
        return false;    
    } */

    ////////////////////////////////////////////
    // Internals to check if a specific action for example, 'accountafterinsert', is recursion blocked for the execute-implementing class and context (test/non-test)
    // NOTE: this is Deprecated
    ////////////////////////////////////////////   
/*     private static boolean isRecursionBlocked (string action, string executeClassName){

        if (debug) System.debug('ZyrinxTriggerArchitecture.isRecursionBlocked');   
        if (debug) System.debug('ZyrinxTriggerArchitecture.isRecursionBlocked.action: ' + action);  
        if (debug) System.debug('ZyrinxTriggerArchitecture.isRecursionBlocked.executeClassName: ' + executeClassName);  
        action = action.toLowerCase();
        getTriggerActionData();
        Boolean retval = false;
        
        if(triggerActionMap == null){
            return false;
        }
        
        if(triggerActionMap.containsKey(action)){
            for (Trigger_Action__mdt ta : triggerActionMap.get(action)){
                if(ta.Execute_Class__c == executeClassName){
                    if (debug) System.debug('ZyrinxTriggerArchitecture.isRecursionBlocked.retval: ' + ta.BlockRecursion__c);
                    return ta.BlockRecursion__c;
                }
            }
        }
        return false;    
    } */

    ////////////////////////////////////////////
    // Internals to handle RecordType pre-filtering if specified in the Trigger_Action__mdt
    ////////////////////////////////////////////  
    // First get active RecordTypes for our Trigger Action SObject
    // NOTE: isavailable was removed because it doesnt recognize sharing rules applied
    ////////////////////////////////////////////      
    private static Map<String,Id> getRecordTypeDevNamesForType(String objectType) {

        Map<String, Id> mapRecordTypes = new Map<String,Id>();

        try{
            SObjectType objToken = Schema.getGlobalDescribe().get(objectType);
            DescribeSObjectResult objDef = objToken.getDescribe();
            Map<String,Schema.RecordTypeInfo> rtMapByDevName = objDef.getRecordTypeInfosByDeveloperName();

            for(Schema.RecordTypeInfo recordType : rtMapByDevName.values()) {
                if(recordType.active){
                    mapRecordTypes.put(recordType.getDeveloperName(), recordType.getRecordTypeId());
                }
            }
        }
        catch(Exception ex){
            if (debug) System.debug('ZyrinxTriggerArchitecture.getRecordTypeDevNamesForType.Exception: ' + ex.getMessage());
            ExceptionUtility.consumeException(ex, 'ZyrinxTriggerArchitecture.getRecordTypeDevNamesForType.Exception: ' + ex.getMessage(), true);
        }
        return mapRecordTypes;
    }
    ////////////////////////////////////////////  
    // Next actually filter the incoming records by RecordType match, and Recursion check
    ////////////////////////////////////////////      
    private static List<sObject> filterRecordsbyRecordTypes(String filterRecordTypes, Map<String,Id> mapRecordTypes, List<sObject> records) {

        if (debug) System.debug('ZyrinxTriggerArchitecture.filterRecordsbyRecordTypes: ' + filterRecordTypes);

        try{

            List<sObject> filteredObjects = new List<sObject>();

            Set<String> filterRecordTypeDeveloperNames = new Set<String>(filterRecordTypes.split(','));
            Set<Id> setRecTypeIds = new Set<Id>();

            for(String strRecType : filterRecordTypeDeveloperNames){
                if(mapRecordTypes.get(strRecType.trim()) != null){
                    setRecTypeIds.add(mapRecordTypes.get(strRecType.trim()));
                }
            }
            
            for(sObject objRecord : records){
                if(setRecTypeIds.contains(objRecord.get('RecordTypeId').toString())){
                    filteredObjects.add(objRecord);
                }
            }
            return filteredObjects;

        }
        catch(Exception ex){
            if (debug) System.debug('ZyrinxTriggerArchitecture.filterRecordsbyRecordTypes.Exception: ' + ex.getMessage());
            ExceptionUtility.consumeException(ex, 'ZyrinxTriggerArchitecture.filterRecordsbyRecordTypes.Exception: ' + ex.getMessage(), true);
            return records;
        }
    }
    ////////////////////////////////////////////  
    // Next filter the incoming records by alreadyProcessed
    ////////////////////////////////////////////      
    private static List<sObject> filterRecordsbyAlreadyProcessed(TriggerParameters tp, Map<String,Set<Id>> recordsAlreadyProcessed, List<sObject> records) {

        if (debug) System.debug('ZyrinxTriggerArchitecture.filterRecordsbyAlreadyProcessed');

        try{

            Set<Id> recordsForThisAction = recordsAlreadyProcessed.get(tp.defaultName);
            List<sObject> filteredObjects = new List<sObject>();

            for(sObject objRecord : records){
                if(!recordsForThisAction.contains(objRecord.Id)){
                    filteredObjects.add(objRecord);
                }
            }
            return filteredObjects;

        }
        catch(Exception ex){
            if (debug) System.debug('ZyrinxTriggerArchitecture.filterRecordsbyAlreadyProcessed.Exception: ' + ex.getMessage());
            ExceptionUtility.consumeException(ex, 'ZyrinxTriggerArchitecture.filterRecordsbyAlreadyProcessed.Exception: ' + ex.getMessage(), true);
            return records;
        }
    }

    ////////////////////////////////////////////
    // Internals to determine if this context is BEFORE or AFTER
    ////////////////////////////////////////////    
    private static Boolean isContextBefore(ZyrinxTriggerArchitecture.TriggerParameters tp)
    {
        return tp.defaultName.toLowerCase().contains('before');
    }

    //////////////////////////////////////////////////////
    // Packages trigger context of caller for use throughout the ZyrinxTriggerArchitecture
    //////////////////////////////////////////////////////
    public static TriggerParameters getTriggerParams(){
        TriggerParameters tp;

        tp = new TriggerParameters(
            trigger.isDelete ? trigger.old : trigger.new,
            trigger.oldMap,
            trigger.newMap,
            trigger.isBefore,
            trigger.isAfter, 
            trigger.isInsert,
            trigger.isUpdate,
            trigger.isDelete,
            trigger.isUndelete
        );

        System.debug('ZyrinxTriggerArchitecture.executeAllMethods: (' + tp.records.size() + ') ' + tp.triggerObject + ' records');
        return tp;
    }
    
    //////////////////////////////////////////////////////
    // Package for trigger context of caller for use throughout the ZyrinxTriggerArchitecture
    //////////////////////////////////////////////////////
    global class triggerParameters{

        global List <SObject> records { get; private set; }
        global Map<Id, SObject> oldMap { get; private set; }
        global Map<Id, SObject> newMap { get; private set; }
        global String triggerObject { get; private set; }
        global boolean isBefore { get; private set; }
        global boolean isAfter { get; private set; }
        global boolean isInsert { get; private set; }
        global boolean isUpdate { get; private set; }
        global boolean isDelete { get; private set; }
        global boolean isUndelete { get; private set; }
        global string action { get; private set; }
        global string defaultName { get; private set; }
        
        global TriggerParameters(){}
        
        global TriggerParameters(List <SObject> recs, 
                Map<Id, SObject> oMap, Map<Id, SObject> nMap,
                Boolean ib, Boolean ia,  Boolean ii, Boolean iu, Boolean id, Boolean iud){

            this.oldMap = omap;
            this.newMap = nmap;
            this.isBefore = ib;
            this.isAfter = ia;
            this.isDelete = id;
            this.isInsert = ii;
            this.isUpdate = iu;
            this.isDelete = id;
            this.isUndelete = iud;
            this.records = recs;
            
            this.triggerObject = this.records[0].getSObjectType().getDescribe().getName();
            
            this.defaultName = setDefaultName(this.triggerObject,
                this.isBefore, this.isAfter,  this.isInsert, this.isUpdate, this.isDelete, this.isUnDelete);
            
            if (this.defaultName.toLowerCase().contains('insert'))
                this.action = 'insert';
            else if (this.defaultName.toLowerCase().contains('update'))
                this.action = 'update';
            else if (this.defaultName.toLowerCase().contains('undelete'))
                this.action = 'undelete';
            else if (this.defaultName.toLowerCase().contains('delete'))
                this.action = 'delete';
         }
    }
    
    //////////////////////////////////////////////////////
    // Logic to convert the context of a call to the format like 'accountafterinsert'
    //////////////////////////////////////////////////////
    private static string setDefaultName(string triggerObject,
                                        Boolean isBefore, Boolean isAfter,  
                                        Boolean isInsert, Boolean isUpdate, 
                                        Boolean isDelete, Boolean isUnDelete){

        string defaultName = triggerObject;
            
        if(isBefore == true){
            defaultName += 'Before';
        } else{
            defaultName += 'After';
        }
        if(isInsert == true){
            defaultName += 'Insert';
        }
        else if(isUpdate == true){
            defaultName += 'Update';
        }
        else if(isDelete == true){
            defaultName += 'Delete';
        }
        else if(isUndelete == true){
            defaultName += 'UnDelete';
        }
        
        return defaultName;
    }   

    //////////////////////////////////////////////////////
    // Logic to map a Trigger Action CMDT to the format like 'accountafterinsert'
    //////////////////////////////////////////////////////
    private static void getDefaultNameFromSetting(Trigger_Action__mdt g)
    {
        if(g.beforeInsert__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'BeforeInsert', g);  
        }
        if(g.beforeUpdate__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'BeforeUpdate', g);  
        }
        if(g.beforeDelete__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'BeforeDelete', g);  
        }
        if(g.afterInsert__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'AfterInsert', g);   
        }
        if(g.afterUpdate__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'AfterUpdate', g);   
        }
        if(g.afterDelete__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'AfterDelete', g);   
        }
        if(g.afterUnDelete__c == true){
            addToTriggerActionMap(g.Object_Name__c + 'AfterUnDelete', g); 
        }
    }   

    //////////////////////////////////////////////////////
    // Logic to add to map a Trigger Action CMDT to the format like 'accountafterinsert'
    //////////////////////////////////////////////////////
    private static void addToTriggerActionMap(string action, Trigger_Action__mdt g)
    {
        string triggerAction = action.toLowerCase();
        
        if(!triggerActionMap.isEmpty() && triggerActionMap.containsKey(triggerAction)){
            List <Trigger_Action__mdt> a = triggerActionMap.get(triggerAction);
            a.add(g);
            triggerActionMap.put(triggerAction,a);
        }
        else{
            List <Trigger_Action__mdt> a = new List <Trigger_Action__mdt>();
            a.add(g);
            triggerActionMap.put(triggerAction,a);
        }
    }
    
}