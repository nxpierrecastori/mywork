/*
(c) 2018 Nexell GmbH
Developed by NEXELL GmbH, Zug (Switzerland)
Developer: Pierre Castori
Created: 05.2018
Version:

Description:

Modifications:
28.08.2018 [PC] Added support of PRoduct backlogs (Requirement__c)

*/
@isTest
private class nx_WorkController_Test {

    static testMethod void myUnitTest()
    {
    	// Create test data
        Account a = new Account(Name = 'testAccount');
        insert a;
        
        Contact c = new Contact(LastName = 'testContact', AccountId = a.Id);
        insert c;
        
        Case testCase = new Case(Subject = 'test', AccountId = a.Id, Description = 'test');
        insert testCase;

        Contract testContract = nx_Helper_TestFramework.setContract('testContract', a.Id);
        
        Workspace__c ws = nx_Helper_TestFramework.setWorkspace('testWorkspace', testContract.ID, a.Id);
        
        Project_Task__c pt = nx_Helper_TestFramework.setProjectTask('testProjectTask', ws.Id, null, 'Main_Task');
        pt.Task_Type__c = 'Task';
        pt.Stage__c = 'New';
        update pt;
        
        Feature__c testFeature = new Feature__c(
        	Name = 'test feature',
        	Workspace__c = ws.Id
        );
        insert testFeature;
        
        Requirement__c pbl = new Requirement__c(
        	Requirement_Title__c = 'test',
        	As_a__c = 'asatest',
        	I_want_to__c = 'iwanttotest',
        	So_that__c = 'sothattest',
        	Status__c = 'Not Started',
        	User_Story_Effort__c = '2',
        	User_Story_Value__c = '8',
        	Workspace__c = ws.Id,
        	Feature__c = testFeature.Id
        );
        insert pbl;
        
        // Run tests
        Test.startTest();
        
        nx_WorkController ctrl = new nx_WorkController();
        
        nx_WorkController.updateWorkItemAfterMove(testCase.Id, nx_WorkController.WAITING, 'Waiting for Customer Approval - Test');
        nx_WorkController.updateWorkItemAfterMove(pt.Id, nx_WorkController.INPROGRESS, null);
        nx_WorkController.updateWorkItemAfterMove(pbl.Id, nx_WorkController.INPROGRESS, null);
        
        ctrl = new nx_WorkController();
        
        Test.stopTest();
        
        // Verify results and do some test coverage
        
        ctrl.getWorkItemStateKeys();
        ctrl.getWorkItemStates();
        ctrl.getUsers();
        
        nx_WorkController.workItemStates.get(nx_WorkController.INPROGRESS).getHelpHtmlText();
        nx_WorkController.WorkItem myWorkItem1 = ctrl.allWorkItemsMap.get(nx_WorkController.WAITING)[0];
        myWorkItem1.getNewTimeTrackLink();
        myWorkItem1.getHasNewComments();
        myWorkItem1.getContactName();
        myWorkItem1.getLatestCommentOrigin();
        myWorkItem1.getLatestCommentText();
        myWorkItem1.getCreatedOrigin();
        myWorkItem1.getModifiedOrigin();
        myWorkItem1.getSfStatus();
        myWorkItem1.getRole();
        myWorkItem1.getIcon();
        
        nx_WorkController.WorkItem myWorkItem2 = ctrl.allWorkItemsMap.get(nx_WorkController.INPROGRESS)[0];
        myWorkItem2.getNewTimeTrackLink();
        myWorkItem2.getHasNewComments();
        myWorkItem2.getContactName();
        myWorkItem2.getLatestCommentOrigin();
        myWorkItem2.getLatestCommentText();
        myWorkItem2.getCreatedOrigin();
        myWorkItem2.getModifiedOrigin();
        myWorkItem2.getSfStatus();
        myWorkItem2.getRole();
        myWorkItem2.getIcon();
        
        nx_WorkController.WorkItem myWorkItem3 = ctrl.allWorkItemsMap.get(nx_WorkController.INPROGRESS)[1];
        myWorkItem3.getNewTimeTrackLink();
        myWorkItem3.getHasNewComments();
        myWorkItem3.getContactName();
        myWorkItem3.getLatestCommentOrigin();
        myWorkItem3.getLatestCommentText();
        myWorkItem3.getCreatedOrigin();
        myWorkItem3.getModifiedOrigin();
        myWorkItem3.getSfStatus();
        myWorkItem3.getRole();
        myWorkItem3.getIcon();
    }
}