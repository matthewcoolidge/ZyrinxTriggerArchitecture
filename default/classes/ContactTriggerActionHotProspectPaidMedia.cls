/*
 * @description: Trigger Action to handle when Contact Hot Prospect/Paid Media flags are updated to true, create opportunity
 * @author: Charlie Faber
 * @date: 2023-10-30
 */
public without sharing class ContactTriggerActionHotProspectPaidMedia extends ZyrinxTriggerArchitecture.asyncProcessing implements ZyrinxTriggerArchitecture.executeMethod {
    public static Constants.User userConstants = new Constants.User();
    public static Constants.Opportunity oppConstants = new Constants.Opportunity();
    public static Constants.Task taskConstants = new Constants.Task();
    public static Constants.Account accConstants = new Constants.Account();
    public static List<Contact> contactsThatNeedTasks = new List<Contact>();
    public static Map<Id, Account> accountsById = new Map<Id, Account>();

    private static User HANDRAISER_BOT {
        get {
            if (HANDRAISER_BOT == null) {
                HANDRAISER_BOT = [SELECT Id FROM User WHERE FirstName = 'Hand Raiser' LIMIT 1];
            }
            return HANDRAISER_BOT;
        }
        set;
    }

    /*
     * @description ZyrinxTriggerArchitecture.executeMethod
     * @param List <SObject> records
     * @param Map <Id, SObject> oldMap
     * @param ZyrinxTriggerArchitecture.triggerParameters tp
     */
    public void execute(
        List<SObject> records,
        Map<Id, SObject> oldMap,
        ZyrinxTriggerArchitecture.triggerParameters tp
    ) {
        List<Contact> filteredContacts = filterHotContacts((List<Contact>) records, oldMap);
        if (!filteredContacts.isEmpty()) {
            List<Opportunity> opportunitiesToUpsert = new List<Opportunity>();
            Map<Id, Opportunity> queuedOppsByAccountId = new Map<Id, Opportunity>();
            Map<Id, Opportunity> existingOppsByAccount = new Map<Id, Opportunity>();
            Map<Id, Boolean> contactsProcessedForNewOpp = new Map<Id, Boolean>();
            accountsById = new Map<Id, Account>([SELECT Id, Name, OwnerId, Account_Status__c, Owner.UserType__c
                                                 FROM Account
                                                 WHERE Id IN :Pluck.ids(Contact.AccountId, filteredContacts)]);
            if (!accountsById.isEmpty()) {
                List<Opportunity> queriedOpps = new List<Opportunity>(
                    [SELECT AccountId, Id, StageName, OwnerId, Owner.UserType__c, Account.Name, Account.Account_Status__c
                     FROM Opportunity
                     WHERE AccountId IN :accountsById.keySet()
                     AND (StageName = :oppConstants.QUEUED_STAGENAME
                     OR StageName NOT IN :oppConstants.SKIP_CREATION_STAGES_HOT_MEDIA)]);
                for (Opportunity opp : queriedOpps) {
                    Boolean isOwnedByHandraiserBot = opp.OwnerId == HANDRAISER_BOT.Id;
                    Boolean isBotUserType = opp.Owner.UserType__c == userConstants.USERTYPE_BOT;
                    Boolean isQueued = opp.StageName == oppConstants.QUEUED_STAGENAME;
                    Boolean isNewBusiness = opp.Account.Account_Status__c == accConstants.NEW_BUSINESS_STATUS;
                    if ((isQueued && !isOwnedByHandraiserBot && isBotUserType) || (isNewBusiness && !isBotUserType)) {
                        queuedOppsByAccountId.put(opp.AccountId, opp);
                    } else if (!oppConstants.SKIP_CREATION_STAGES_HOT_MEDIA.contains(opp.StageName) &&
                        !isNewBusiness && ((isOwnedByHandraiserBot && isQueued) || !isBotUserType)) {
                        existingOppsByAccount.put(opp.AccountId, opp);
                    }
                }

                for (Contact con : filteredContacts) {
                    Account acc = accountsById.get(con.AccountId);
                    Opportunity existingOpp = existingOppsByAccount?.get(con.AccountId);
                    Opportunity queuedOpp = queuedOppsByAccountId.get(con.AccountId);
                    if (queuedOpp != null) {
                        opportunitiesToUpsert.add(updateHotOpportunity(con, queuedOpp));
                    } else if (existingOpp == null && queriedOpps?.isEmpty()) {
                        if (!contactsProcessedForNewOpp.containsKey(con.Id)) {
                            contactsProcessedForNewOpp.put(con.Id, true);
                            opportunitiesToUpsert.add(createNewHotOpportunity(con, acc));
                        }
                    } else if (
                        accountsById.get(con.AccountId)?.Account_Status__c == accConstants.NEW_BUSINESS_STATUS &&
                        existingOpp != null && existingOpp?.OwnerId != HANDRAISER_BOT.Id &&
                        !oppConstants.SKIP_CREATION_STAGES_HOT_MEDIA.contains(existingOpp?.StageName)) {
                        opportunitiesToUpsert.add(updateHotOpportunity(con, existingOpp));
                    }
                }
                if (!opportunitiesToUpsert.isEmpty()) {
                    upsertOpportunityAndAssignAccount(opportunitiesToUpsert);
                }

                if (!contactsThatNeedTasks.isEmpty()) {
                    insert createTasksForContacts(contactsThatNeedTasks);
                }
            }
        }
    }

    /**
     * @description Filter Contacts where Hot Prospect or Paid Media checkboxes are set to true
     * @param List<Contact> newContacts
     * @param Map<Id, Contact> oldContacts
     * @return List<Contact> filteredContacts
     */
    public static List<Contact> filterHotContacts(List<Contact> newContacts, Map<Id, SObject> oldContacts) {
        List<Contact> filteredContacts = new List<Contact>();
        for (Contact con : newContacts) {
            Contact oldCon = (Contact) oldContacts?.get(con?.Id);
            Boolean isHotProspectNewOrChanged =
                con.HotProspect__c == true && (oldCon == null || oldCon?.HotProspect__c == false);
            Boolean isPaidMediaNewOrChanged =
                con.PaidMedia__c == true && (oldCon == null || oldCon?.PaidMedia__c == false);

            if (isHotProspectNewOrChanged || isPaidMediaNewOrChanged) {
                filteredContacts.add(con);
                contactsThatNeedTasks.add(con);
            }
        }
        return filteredContacts;
    }

    /**
     * @description Create new Hot Opportunity from Contact data
     * @param Contact con
     * @return Opportunity newOpp
     */
    public static Opportunity createNewHotOpportunity(Contact con, Account acc) {
        Opportunity newOpp = new Opportunity();
        String opportunityType = con.HotProspect__c == true
            ? oppConstants.HOT_MEDIA_OPP_TYPE
            : oppConstants.PAID_MEDIA_OPP_TYPE;
        newOpp.Name = opportunityType + ' - ' + acc.Name;
        newOpp.RecordTypeId = oppConstants.NEW_RT_ID;
        newOpp.AccountId = con.AccountId;
        newOpp.Hot_Opportunity__c = con.HotProspect__c;
        newOpp.Paid_Media_Opportunity__c = con.PaidMedia__c;
        newopp.OwnerId = assignOpportunityOwner(con, newOpp);
        newOpp.StageName = oppConstants.QUEUED_STAGENAME;
        newOpp.CloseDate = Date.today().adddays(30);
        return newOpp;
    }

    /**
     * @description Update Hot Prospect on Opportunity based on Contact Data, same as insert.
     * @param Contact con, Opportunity opp
     * @param Opportunity opp
     * @return Opportunity opp
     */
    public static Opportunity updateHotOpportunity(Contact con, Opportunity opp) {
        String opportunityType = con.HotProspect__c == true
            ? oppConstants.HOT_MEDIA_OPP_TYPE
            : oppConstants.PAID_MEDIA_OPP_TYPE;
        opp.Name = opportunityType + ' - ' + opp.Account.Name;
        opp.Hot_Opportunity__c = con.HotProspect__c;
        opp.Paid_Media_Opportunity__c = con.PaidMedia__c;
        opp.OwnerId = assignOpportunityOwner(con, opp);
        return opp;
    }

    /**
     * @description Overloaded Method: Returns Opportunity Owner based on Contact's Account Status and Opportunity Type
     * @param Contact con
     * @param Opportunity opp
     * @return Id ownerId
     */
    public static Id assignOpportunityOwner(Contact con, Opportunity opp) {
        Boolean isAccountActive = accountsById?.get(con.AccountId)?.Account_Status__c == accConstants.ACCOUNT_STATUS_ACTIVE;
        Boolean isAccountNewBusiness = accountsById?.get(con.AccountId)?.Account_Status__c == accConstants.NEW_BUSINESS_STATUS;
        Boolean isCurrentOwnerABot = (opp.Owner?.UserType__c == userConstants.USERTYPE_BOT) || 
                                     (accountsById?.get(con.AccountId)?.Owner?.UserType__c == userConstants.USERTYPE_BOT);
    
        if ((opp.Hot_Opportunity__c || opp.Paid_Media_Opportunity__c)) {
            if (isAccountActive) {
                return accountsById?.get(con.AccountId)?.OwnerId;
            } else if (!isCurrentOwnerABot && opp.OwnerId != null) {
                return opp.OwnerId;
            } else if (isAccountNewBusiness && isCurrentOwnerABot) {
                return HANDRAISER_BOT?.Id;
            }
        }
    
        return opp.OwnerId == null ? accountsById?.get(con.AccountId)?.OwnerId : opp.OwnerId;
    }
    
    /**
     * @description Overloaded Method: Returns Opportunity Owner based on Account Status and Opportunity Type
     * @param Account acc
     * @param Opportunity opp
     * @return Id ownerId
     */
    public static Id assignOpportunityOwner(Account acc, Opportunity opp) {

        Boolean isAccountActive = acc.Account_Status__c == accConstants.ACCOUNT_STATUS_ACTIVE;
        Boolean isAccountNewBusiness = acc.Account_Status__c == accConstants.NEW_BUSINESS_STATUS;
        Boolean isCurrentOwnerABot = opp.Owner?.UserType__c == userConstants.USERTYPE_BOT;

        if (opp.Hot_Opportunity__c || opp.Paid_Media_Opportunity__c) {
            if (isAccountActive) {
                return acc.OwnerId;
            } else if (!isCurrentOwnerABot && opp.OwnerId != null) {
                return opp.OwnerId;
            } else if (isAccountNewBusiness && isCurrentOwnerABot) {
                return HANDRAISER_BOT.Id;
            } else if (!isAccountActive && !isAccountNewBusiness) {
                return HANDRAISER_BOT.Id;
            }
        }
        return opp.OwnerId == null ? acc.OwnerId : opp.OwnerId;
    }

    /*
     * @description Helper method to upsert Opportunities
     * @param List<Opportunity> opportunitiesToUpsert
     * @return void
     */
    public static void upsertOpportunityAndAssignAccount(List<Opportunity> opportunitiesToUpsert) {
        List<Account> accToUpdate = new List<Account>();
        try {
            system.debug('opportunitiesToUpsert: ' + opportunitiesToUpsert);
            upsert opportunitiesToUpsert;
            for (Opportunity opp : opportunitiesToUpsert) {
                Account acc = new Account(Id = opp.AccountId);
                if (opp.Account.Account_Status__c != accConstants.ACCOUNT_STATUS_ACTIVE) {
                    acc.OwnerId = assignOpportunityOwner(acc, opp);
                    accToUpdate.add(acc);
                }
            }
            update accToUpdate;
        } catch (Exception e) {
            String message = e.getMessage();
            ExceptionUtility.consumeException(e, message, true);
        }
    }

    public static List<Task> createTasksForContacts(List<Contact> contacts) {
        List<Task> tasks = new List<Task>();
        for (Contact con : contacts) {
            if (accountsById?.get(con.AccountId)?.Account_Status__c != accConstants.ACCOUNT_STATUS_ACTIVE) {
                continue;
            }
            Task tsk = new Task();
            tsk.RecordTypeId = taskConstants.AM_ESC_RTID;
            tsk.OwnerId = con.OwnerId;
            tsk.WhatId = con.AccountId;
            tsk.Subject = taskConstants.AM_ESC_HANDRAISER_SUBJECT + accountsById?.get(con.AccountId)?.Name;
            tsk.Type = taskConstants.AM_ESC_TYPE;
            tsk.Escalation_Reason__c = taskConstants.HANDRAISER_ESC_REASON;
            tsk.WhoId = con.Id;
            tsk.ActivityDate = Date.today().addDays(3);
            tsk.Description = taskConstants.AM_ESC_HANDRAISER_DESC;
            tsk.Status = taskConstants.STATUS_OPEN;
            tsk.Priority = taskConstants.PRIORITY_URGENT;
            tasks.add(tsk);
        }
        return tasks;
    }
}