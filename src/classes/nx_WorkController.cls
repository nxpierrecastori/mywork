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
public without sharing class nx_WorkController
{
	/****** Status configuration parameters *******/
	
	public static final String UNASSIGNED 	= 'Unassigned';
	public static final String TODO 		= 'ToDo';
	public static final String INPROGRESS 	= 'InProgress';
	public static final String WAITING 		= 'Waiting';
	public static final String DONE 		= 'Done';
	
	private static final Integer CLOSED_WORKITEMS_OFFSET = -5;
	
	// Id of the nexell case queue (to handle the new case)
	private transient final String queueId = [SELECT Id FROM GROUP WHERE Type = 'Queue' AND DeveloperName = 'QueueNexellBusinessSupport'].Id;
    	
	private static final Set<String> caseUnassignedStates = new Set<String>();
	private static final Set<String> caseInProgressStates = new Set<String>{ 'In progress' };
    private static final Set<String> caseWaitingStates = new Set<String>{ 'Waiting for Customer Activation', 'Waiting for Customer Approval - Test', 'Waiting for Customer Approval - Prod', 'Waiting for Customer Response', 'Escalated - Waiting for Feedback' };
    private static final Set<String> caseToDoStates = new Set<String>{ 'New', 'Confirm effort / price', 'Issue Tracking' };
    private static final Set<String> caseDoneStates = new Set<String>{ 'Closed', 'Closed Escalated', 'On Hold' };
    
    private static final Set<String> ptUnassignedStates = new Set<String>();
    private static final Set<String> ptInProgressStates = new Set<String>{ 'In Progress','Estimation in Progress', 'In Testing' };
 	private static final Set<String> ptWaitingStates = new Set<String>{ 'Estimation Done', 'Feedback Required', 'Planning Done', 'Waiting for Customer Activation', 'Ready for Test', 'Waiting for Customer Approval - Test', 'Waiting for Customer Approval - Production' };
 	private static final Set<String> ptToDoStates = new Set<String>{ 'New', 'Estimation Required', 'Planning Required','Approved by Customer - Test', 'Deploy to Production', 'Test failed' };
    private static final Set<String> ptDoneStates = new Set<String>{ 'Done', 'On Hold', 'Cancelled by Customer', 'Approved by Customer - Production', 'Deployed to Production' };
    
    private static final Set<String> pblUnassignedStates = new Set<String>();
    private static final Set<String> pblInProgressStates = new Set<String>{ 'In Progress','Estimation in Progress', 'In Testing' };
 	private static final Set<String> pblWaitingStates = new Set<String>{ 'Pending', 'Estimation Done', 'Feedback Required', 'Planning Done', 'Waiting for Customer Activation', 'Ready for Test', 'Waiting for Customer Approval - Test', 'Waiting for Customer Approval - Production' };
 	private static final Set<String> pblToDoStates = new Set<String>{ 'Not Started', 'Estimation Required', 'Planning Required','Approved by Customer - Test', 'Deploy to Production', 'Test failed' };
    private static final Set<String> pblDoneStates = new Set<String>{ 'Rejected', 'Done', 'On Hold', 'Cancelled by Customer', 'Approved by Customer - Production', 'Deployed to Production' };
    
    // A description of the workitem status and how it links to case status and project task stages
	public class WorkItemStatus {
		public String label {get; private set;}
		public Set<String> relatedCaseStatuses {get; private set;}
		public Set<String> relatedProjectTaskStatuses {get; private set;}
		public Set<String> relatedProductBacklogStatuses {get; private set;}
		public List<SelectOption> getCaseSelectOptions() { return set2Select(this.relatedCaseStatuses); }
		public List<SelectOption> getPTSelectOptions() { return set2Select(this.relatedProjectTaskStatuses); }
		public List<SelectOption> getPBLSelectOptions() { return set2Select(this.relatedProductBacklogStatuses); }
		
		public WorkItemStatus(String label,
							  Set<String> relatedCaseStatuses,
							  Set<String> relatedProjectTaskStatuses,
							  Set<String> relatedProductBacklogStatuses)
		{
			this.label = label;
			this.relatedCaseStatuses = relatedCaseStatuses;
			this.relatedProjectTaskStatuses = relatedProjectTaskStatuses;
			this.relatedProductBacklogStatuses = relatedProductBacklogStatuses;
		}
		
		public String getHelpHtmlText()
		{
			String result = '';
			
			result += 'This column maps to the following status:<br/><br/>';
			
			if (this.label == workItemStates.get(UNASSIGNED).label)
			{
				result += 'Cases<br/><ul>';
				result += '<li>New and case is owned by the Nexell Queue</li>';
				result += '</ul><br/>';
				result += 'Will be assigned to you if case is moved to another column.';
			}
			else
			{
				result += 'Cases<br/><ul>';
				for (SelectOption status : this.getCaseSelectOptions())
				{
					result += '<li>' + status.getLabel() + '</li>';
				}
				result += '</ul><br/>';
				
				result += 'Project Tasks<br/><ul>';
				for (SelectOption status : this.getPTSelectOptions())
				{
					result += '<li>' + status.getLabel() + '</li>';
				}
				result += '</ul><br/>';
				
				result += 'Product backlogs<br/><ul>';
				for (SelectOption status : this.getPBLSelectOptions())
				{
					result += '<li>' + status.getLabel() + '</li>';
				}
				result += '</ul><br/>';
			}
			
			if (this.label == workItemStates.get(DONE).label)
			{
				result += 'Work items in the ' + workItemStates.get(DONE).label + ' state will disappear after ' + (-CLOSED_WORKITEMS_OFFSET) + ' days.';
			}
			
			return result;
		}
	}
	
	public static final Map<String, WorkItemStatus> workItemStates = new Map<String, WorkItemStatus> {
		UNASSIGNED 	=> new WorkItemStatus('Unassigned', caseUnassignedStates, ptUnassignedStates, pblUnassignedStates),
		TODO 		=> new WorkItemStatus('To do', caseToDoStates, ptToDoStates, pblToDoStates),
		INPROGRESS 	=> new WorkItemStatus('In progress', caseInProgressStates, ptInProgressStates, pblInProgressStates),
		WAITING 	=> new WorkItemStatus('Waiting', caseWaitingStates, ptWaitingStates, pblWaitingStates),
		DONE		=> new WorkItemStatus('Done', caseDoneStates, ptDoneStates, pblDoneStates)
	};
	
    public List<String> getWorkItemStateKeys() { return new List<String>(workItemStates.keyset()); }
    
	public Map<String, WorkItemStatus> getWorkItemStates() { return workItemStates; }
	
	public User currentUser {get; set;}
	
    /* ********************************** WORKITEM CLASS ************************************************************** */
    
    public class WorkItem
    {
    	private Case c;
    	private Project_Task__c pt;
    	private Requirement__c pbl;
    	
    	public String id { get; private set; }
    	public String status { get; private set; }
    	public String name { get; private set; }
    	public String details { get; private set; }
    	public String priority { get; private set; }
    	public String account_name { get; private set; }
    	public String account_id { get; private set; }
    	public List<Credentials__c> credentials { get; private set; }
    	
    	public Boolean getIsCase() { return c != null; }
    	public Boolean getIsPT() { return pt != null; }
    	public Boolean getIsPBL() { return pbl != null; }
    	
    	public String getRole() {
    		if (this.getIsCase()) return 'Case';
    		if (this.getIsPT()) return 'PT';
    		if (this.getIsPBL()) return 'PBL';
    		return '';
    	}
    	
    	// Configures the icon for each workitem type
    	// Icon to be found in https://fontawesome.com/v4.7.0/icons/
    	public String getIcon() {
    		if (this.getIsCase()) return 'suitcase';
    		if (this.getIsPT()) return 'tasks';
    		if (this.getIsPBL()) return 'book';
    		return '';
    	}
    	
    	public String getLatestCommentText()
    	{
    		String result = '';
    		
    		if (this.getIsCase() && c.CaseComments != null && !c.CaseComments.isEmpty() && c.CaseComments[0].CommentBody != null)
    		{
    			result = c.CaseComments[0].CommentBody.replace('\n','<br/>');
    		}
    		else if (this.getIsPT())
    		{
    			result = '-- None --';
    		}
    		else if (this.getIsPBL())
    		{
    			result = '-- None --';
    		}
    		
    		return result;
    	}
    	
    	public String getLatestCommentOrigin()
    	{
    		if (this.getIsCase() && c.CaseComments != null && !c.CaseComments.isEmpty())
    		{
    			return c.CaseComments[0].CreatedDate + ' by ' + c.CaseComments[0].CreatedBy.Name;
    		}
    		else
    		{
    			return '';
    		}
    	}
    	
    	public String getCreatedOrigin()
    	{
    		String result = '';
    		
    		if (this.getIsCase())
    		{
    			result = c.CreatedDate + ' by ' + c.CreatedBy.Name;
    		}
    		else if (this.getIsPT())
    		{
    			result = pt.CreatedDate + ' by ' + pt.CreatedBy.Name;
    		}
    		else if (this.getIsPBL())
    		{
    			result = pbl.CreatedDate + ' by ' + pbl.CreatedBy.Name;
    		}
    		
    		return result;
    	}
    	
    	public String getModifiedOrigin()
    	{
    		String result = '';
    		
    		if (this.getIsCase())
    		{
    			result = c.LastModifiedDate + ' by ' + c.LastModifiedBy.Name;
    		}
    		else if (this.getIsPT())
    		{
    			result = pt.LastModifiedDate + ' by ' + pt.LastModifiedBy.Name;
    		}
    		else if (this.getIsPBL())
    		{
    			result = pbl.LastModifiedDate + ' by ' + pbl.LastModifiedBy.Name;
    		}
    		
    		return result;
    	}
    	
    	public String getContactName()
    	{
    		String result;
    		
    		if (this.getIsCase() && c.ContactId != null)
    		{
    			result = c.Contact.Name;
    		}
    		else if (this.getIsPT() && pt.Contact__c != null)
    		{
    			result = pt.Contact__r.Name;
    		}
    		else
    		{
    			result = '';
    		}
    		
    		if (!String.isBlank(result))
    		{
    			result = '(' + result + ')';
    		}
    		
    		return result;
    	}
    	
    	public Boolean getHasNewComments()
    	{
    		Boolean result = false;
    		
    		if (this.getIsCase())
    		{
    			result = c.HasCommentsUnreadByOwner;
    		}
    		else
    		{
    			result = false;
    		}
    		
    		return result;
    	}
    	
    	public String getNewTimeTrackLink()
    	{
    		String result;
    		
    		if (this.getIsCase())
    		{
    			result =	'/a00/e?' + //retURL=%2F' + this.Id + '&cancelURL=%2F' + this.Id + 
							'CF00N20000003ZO4R=' + this.c.Workspace__r.Name +
							'&CF00N20000003ZO4R_lkid=' + this.c.Workspace__r.Id +
							'&CF00N20000000i5Nx=' + this.c.Workspace__r.Contract__r.ContractNumber +
							'&CF00N20000000i5Nx_lkid=' + this.c.Workspace__r.Contract__r.Id +
							'&CF00N20000000i5Fs=' + this.c.Account.Name +
							'&CF00N20000000i5Fs_lkid=' + this.c.AccountId +
							'&CF00N20000000i5EW=' + this.c.CaseNumber +
							'&CF00N20000000i5EW_lkid=' + this.Id +
							'&Name=' + this.c.CaseNumber;
    		}
    		else if (this.getIsPT())
    		{
    			result =	'/a00/e?' + // retURL=%2F' + this.Id + '&cancelURL=%2F' + this.Id +
    						'CF00N20000003ZO4R=' + this.pt.Workspace__r.Name +
    						'&CF00N20000003ZO4R_lkid=' + this.pt.Workspace__r.Id +
    						'&CF00N20000000i5Nx=' + this.pt.Workspace__r.Contract__r.ContractNumber +
    						'&CF00N20000000i5Nx_lkid=' + this.pt.Workspace__r.Contract__r.Id +
    						'&CF00N20000000i5Fs=' + this.pt.Workspace__r.Account__r.Name +
    						'&CF00N20000000i5Fs_lkid=' + this.pt.Workspace__r.Account__r.Id +
    						'&CF00N20000003ZO4Q=' + this.pt.Name +
    						'&CF00N20000003ZO4Q_lkid=' + this.Id +
    						'&Name=' + this.pt.Name;
    		}
    		else if (this.getIsPBL())
    		{
    			result =	'/a00/e?' + // retURL=%2F' + this.Id + '&cancelURL=%2F' + this.Id +
    						'CF00N20000003ZO4R=' + this.pbl.Feature__r.Workspace__r.Name +
    						'&CF00N20000003ZO4R_lkid=' + this.pbl.Feature__r.Workspace__r.Id +
    						'&CF00N20000000i5Nx=' + this.pbl.Feature__r.Workspace__r.Contract__r.ContractNumber +
    						'&CF00N20000000i5Nx_lkid=' + this.pbl.Feature__r.Workspace__r.Contract__r.Id +
    						'&CF00N20000000i5Fs=' + this.pbl.Feature__r.Workspace__r.Account__r.Name +
    						'&CF00N20000000i5Fs_lkid=' + this.pbl.Feature__r.Workspace__r.Account__r.Id +
    						'&CF00N20000003ZO4Q=' + this.pbl.Name +
    						'&CF00N20000003ZO4Q_lkid=' + this.Id +
    						'&Name=' + this.pbl.Name;
    		}
    		
    		return result;
    	}
    	
    	public String getSfStatus()
    	{
    		String result = '';
    		
    		if (this.getIsCase())
    		{
    			result = c.Status;
    		}
    		else if (this.getIsPT())
    		{
    			result = pt.Stage__c;
    		}
    		else if (this.getIsPBL())
    		{
    			result = pbl.Status__c;
    		}
    		
    		return result;
    	}
    	
    	// Constructor
    	public WorkItem()
    	{
    		this.credentials = new List<Credentials__c>();
    	}
    }
    
    
    /* ************************************************************************************************ */
    
    // The list of all work items for the current user to be displayed in the Kanban
    public Map<String, List<WorkItem>> allWorkItemsMap {get; set;}
    
    // Constructor
    // Initialise the work item list with the values corresponding to the current user
    public nx_WorkController()
    {
    	Datetime referenceDate = Datetime.now().addDays(CLOSED_WORKITEMS_OFFSET);
    	
    	allWorkItemsMap = new Map<String, List<WorkItem>>();
    	for (String status : workItemStates.keyset())
    	{
    		allWorkItemsMap.put(status, new List<WorkItem>());
    	}
    	
    	// By default userId is the current user. Else it gets it from the URL parameters.
    	Id userId = ApexPages.currentPage().getParameters().get('userId');
    	if (userId == null)
    	{
    		userId = UserInfo.getUserId();
    	}
    	
    	currentUser = [SELECT Id, FirstName, LastName FROM User WHERE Id = :userId];
    	
    	Set<Id> workItemsAccountIds = new Set<Id>();
    	
    	// Processing for cases
    	for (Case c : [ SELECT Id, OwnerId, CaseNumber, Priority, Status, Subject, Description, AccountId, Account.Name,
    						   ContactId, Contact.Name, Workspace__r.Name, Workspace__r.Id, Workspace__r.Contract__r.ContractNumber,
    						   Workspace__r.Contract__r.Id, HasCommentsUnreadByOwner, HasSelfServiceComments, 
    						   CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name,
    						   (SELECT Id, ParentId, IsPublished, CommentBody, CreatedDate, CreatedBy.Name FROM CaseComments ORDER BY CreatedDate DESC LIMIT 1)
    					FROM Case
    					WHERE (OwnerId = :userId OR (OwnerId = :queueId AND Status = 'New'))
    						AND (Status NOT IN :caseDoneStates OR (Status IN :caseDoneStates AND LastModifiedDate >= :referenceDate))
    					ORDER BY LastModifiedDate DESC ] )
        {
        	WorkItem wi = new WorkItem();
        	sfCase2workItem(c, wi);
        	// Skip cases with no status (not normal)
        	if (wi.status == null) continue;
        	allWorkItemsMap.get(wi.status).add(wi);
        	workItemsAccountIds.add(c.AccountId);
        }
    	
    	// Processing for PT
    	for (Project_Task__c pt : [SELECT Id, OwnerId, Name, Account__c, Workspace__r.Account__r.Name, Workspace__r.Account__r.Id, Workspace__r.Account__c,
    									  Stage__c, Customer_Task_Priority__c, Note__c, Contact__c, Workspace__r.Name, Workspace__r.Id,
    									  Workspace__r.Contract__r.ContractNumber, Workspace__r.Contract__r.Id,
    									  Contact__r.Name, Due_Date_User_Acceptance_Test_Planned__c, Due_Date_Production_Planned__c,
    									  CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
    							   FROM Project_Task__c
    							   WHERE OwnerId = :userId
    							   		AND (Stage__c NOT IN :ptDoneStates OR (Stage__c IN :ptDoneStates AND LastModifiedDate >= :referenceDate))
    							   ORDER BY LastModifiedDate DESC])
    	{
    		WorkItem wi = new WorkItem();
        	sfProjectTask2workItem(pt, wi);
        	// Skip pts with no status (not normal)
        	if (wi.status == null) continue;
        	allWorkItemsMap.get(wi.status).add(wi);
        	workItemsAccountIds.add(pt.Workspace__r.Account__c);
    	}
    	
    	// Processing for PBL
    	for (Requirement__c pbl : [SELECT Id, Name, Feature__r.Workspace__r.Account__r.Name, Feature__r.Workspace__r.Account__r.Id, Feature__r.Workspace__r.Account__c,
    									  Status__c, User_Story_Priority__c, Comments__c, Feature__r.Workspace__r.Name, Feature__r.Workspace__r.Id,
    									  Feature__r.Workspace__r.Contract__r.ContractNumber, Feature__r.Workspace__r.Contract__r.Id,
    									  Requirement_Title__c, As_a__c, I_want_to__c, So_that__c,
    									  CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
    							   FROM Requirement__c
    							   WHERE LastModifiedById = :userId
    							   		AND (Status__c NOT IN :ptDoneStates OR (Status__c IN :ptDoneStates AND LastModifiedDate >= :referenceDate))
    							   ORDER BY LastModifiedDate DESC])
    	{
    		WorkItem wi = new WorkItem();
        	sfProductBacklog2workItem(pbl, wi);
        	// Skip pbls with no status (not normal)
        	if (wi.status == null) continue;
        	allWorkItemsMap.get(wi.status).add(wi);
        	workItemsAccountIds.add(pbl.Feature__r.Workspace__r.Account__c);
    	}
    	
    	// Get the credentials and store them into the work item
    	Map<Id, List<Credentials__c>> account2Credentials = new Map<Id, List<Credentials__c>>();
    	for (Credentials__c credential : [SELECT Id, Account__c, Name, Login_Url__c FROM Credentials__c WHERE Account__c IN :workItemsAccountIds])
    	{
    		List<Credentials__c> cl = account2Credentials.get(credential.Account__c);
    		if (cl == null)
    		{
    			account2Credentials.put(credential.Account__c, new List<Credentials__c>());
    		}
    		account2Credentials.get(credential.Account__c).add(credential);
    	}
		for (List<WorkItem> wiList : allWorkItemsMap.values())
		{
			for (WorkItem wi : wiList)
			{
				if (wi.account_id != null && account2Credentials.get(wi.account_id) != null)
				{
					wi.credentials = account2Credentials.get(wi.account_id);
				}
			}
		}
    }
    
    //
    // Translates case attributes to work item ones
    //
    private void sfCase2workItem(Case c, WorkItem wi)
    {
    	wi.c = c;
    	wi.id = c.Id;
    	wi.account_name = c.Account.Name;
    	wi.account_id = c.AccountId;
    	// Rule for priority: exact match except for Information only which is mapped to low.
    	if (c.Priority == 'Information only')
    	{
    		wi.Priority = 'Low';
    	}
    	else
    	{
    		wi.Priority = c.Priority;
    	}
    	if (c.Description != null)
    	{
    		wi.Details = c.Description.replace('\n','<br/>');	// not rich text, at least put new lines back
    	}
    	else
    	{
    		wi.Details = '';
    	}
    	wi.Name = c.CaseNumber + ' - ' + c.Subject;
    	for (String status : workItemStates.keyset())
    	{
    		// Special case for new cases
    		if (c.Status == 'New' && c.OwnerId == queueId)
    		{
	    		wi.Status = UNASSIGNED;
	    		break;
    		}
    		
	    	if (workItemStates.get(status).relatedCaseStatuses.contains(c.Status))
	    	{
	    		wi.Status = status;
	    		break;
	    	}
    	}
    }
    
    //
    // Translates project task attributes to work item ones
    //
    private void sfProjectTask2workItem(Project_Task__c pt, WorkItem wi)
    {
    	wi.pt = pt;
    	wi.id = pt.Id;
    	wi.account_name = pt.Account__c;
    	wi.account_id = pt.Workspace__r.Account__c;
    	// Rule for priority: 0 is highest, 1 is medium, all other values are low.
    	if (pt.Customer_Task_Priority__c == 0)
    	{
    		wi.Priority = 'High';
    	}
    	else if (pt.Customer_Task_Priority__c == 1)
    	{
    		wi.Priority = 'Medium';
    	}
    	else
    	{
    		wi.Priority = 'Low';
    	}
    	wi.Details = pt.Note__c;	// already rich text
    	wi.Name = pt.Name;
    	for (String status : workItemStates.keyset())
    	{
	    	if (workItemStates.get(status).relatedProjectTaskStatuses.contains(pt.Stage__c))
	    	{
	    		wi.Status = status;
	    		break;
	    	}
    	}
    }
    
    //
    // Translates product backlog attributes to work item ones
    //
    private void sfProductBacklog2workItem(Requirement__c pbl, WorkItem wi)
    {
    	wi.pbl = pbl;
    	wi.id = pbl.Id;
    	wi.account_name = pbl.Feature__r.Workspace__r.Account__r.Name;
    	wi.account_id = pbl.Feature__r.Workspace__r.Account__c;
    	// Rule for priority: 13/1 = 13 is highest, 1/13 is smallest.
    	if (pbl.User_Story_Priority__c >= 8)
    	{
    		wi.Priority = 'High';
    	}
    	else if (pbl.User_Story_Priority__c >= 4)
    	{
    		wi.Priority = 'Medium';
    	}
    	else
    	{
    		wi.Priority = 'Low';
    	}
    	wi.Details = 'As a ' + pbl.As_a__c + '<br>';
    	wi.Details += 'I want to ' + pbl.I_want_to__c + '<br>';
    	wi.Details += 'So that ' + pbl.So_that__c + '<br>';
    	wi.Name = pbl.Name + ' - ' + pbl.Requirement_Title__c;
    	for (String status : workItemStates.keyset())
    	{
	    	if (workItemStates.get(status).relatedProductBacklogStatuses.contains(pbl.Status__c))
	    	{
	    		wi.Status = status;
	    		break;
	    	}
    	}
    }
    
    /* *************************************************************************************** */

    private static List<SelectOption> set2Select(Set<String> theList)
    {
    	List<SelectOption> lso = new List<SelectOption>();
    	
    	for (String s : theList)
    	{
    		lso.add( new SelectOption(s, s) );
    	}
    	
    	return lso;
    }
    
    public List<User> getUsers()
    {
    	return [SELECT Id, Name
    			FROM User
    			WHERE IsActive = true
    				AND ProfileId IN (SELECT Id
    								  FROM Profile
    								  WHERE Name IN ('System Administrator',
    								 				 'Nexell Internal User',
    								 				 'Nexell Internal User (GE)',
    								 				 'Nexell Chatter Only User (External)',
    								 				 'Nexell Chatter Only User (Internal)'))
    			ORDER BY FirstName ASC];	
    }
    
    
	/* *************************************************************************************** */
	
	// Status assignments for case updates
	private static String workItemStatus2CaseStatus(String workItemStatus, String caseStatus)
	{
		if (workItemStatus == UNASSIGNED) return 'New';
		if (workItemStatus == INPROGRESS) return 'In progress';
		if (workItemStatus == TODO) return ( String.isBlank(caseStatus)?'New':caseStatus );
		if (workItemStatus == WAITING) return ( String.isBlank(caseStatus)? 'Waiting for Customer Approval - Test':caseStatus );
		if (workItemStatus == DONE) return 'Closed';
		
		return 'In progress';  // Default which will never occur :)
	}
	
	// Status assignments for pt updates
	private static String workItemStatus2ptStage(String workItemStatus, String ptStage)
	{
		if (workItemStatus == UNASSIGNED) return 'New';
		if (workItemStatus == INPROGRESS) return 'In progress';
		if (workItemStatus == TODO) return ( String.isBlank(ptStage)?'New':ptStage );
		if (workItemStatus == WAITING) return ( String.isBlank(ptStage)?'Waiting for Customer Approval - Test':ptStage );
		if (workItemStatus == DONE) return 'Done';
		
		return 'In progress';  // Default which will never occur :)
	}
	
	// Status assignments for pbl updates
	private static String workItemStatus2pblStage(String workItemStatus, String pblStage)
	{
		if (workItemStatus == UNASSIGNED) return 'Not Started';
		if (workItemStatus == INPROGRESS) return 'In progress';
		if (workItemStatus == TODO) return ( String.isBlank(pblStage)?'Not Started':pblStage );
		if (workItemStatus == WAITING) return ( String.isBlank(pblStage)?'Waiting for Customer Approval - Test':pblStage );
		if (workItemStatus == DONE) return 'Done';
		
		return 'In progress';  // Default which will never occur :)
	}

	// Error status returned to VF page
	public class UpdateStatus {
        public Boolean isSuccess;
        public String message;
    }

	// Actual update operation called from VF page when workitem is moved from one column to another
    @RemoteAction
    public static UpdateStatus updateWorkItemAfterMove( String workItemId, String workItemStatus, String sfItemStatus )
	{
		UpdateStatus updatedDetails = new UpdateStatus();
		updatedDetails.isSuccess = false;
		updatedDetails.message = 'Unknown problem';
		
		try
		{	
			String objectType = String.valueOf( ((Id)workItemId).getSObjectType() );
			
			if (objectType == 'Case')
			{
				Case c = [SELECT Id, Subject, Status, OwnerId FROM Case WHERE Id = :workItemId];
				c.Status = workItemStatus2CaseStatus(workItemStatus, sfItemStatus);
				c.OwnerId = UserInfo.getUserId(); // always assign current user Id in case coming from New and owner is the Nexell queue

	       		updatedDetails.isSuccess = true;
	        	updatedDetails.message = String.format( '{0} was moved successfully to {1}', new List<String>{ c.Subject, workItemStatus.toUppercase() + (String.isBlank(sfItemStatus)?'':' / ' + sfItemStatus) } );
				
				update c;
			}
			else if (objectType == 'Project_Task__c')
			{
				Project_Task__c pt = [SELECT Id, Name, Stage__c FROM Project_Task__c WHERE Id = :workItemId];
				pt.Stage__c = workItemStatus2ptStage(workItemStatus, sfItemStatus);
				
				// To comply with validation rules
				if (pt.Stage__c == 'Waiting for Customer Approval - Test' && pt.Due_Date_User_Acceptance_Test_Planned__c == null)
				{
					pt.Due_Date_User_Acceptance_Test_Planned__c = Date.today();
				}
				if (pt.Stage__c == 'Waiting for Customer Approval - Production' && pt.Due_Date_Production_Planned__c == null)
				{
					pt.Due_Date_Production_Planned__c = Date.today();
				}

	       		updatedDetails.isSuccess = true;
	        	updatedDetails.message = String.format( '{0} was moved successfully to {1}', new List<String>{ pt.Name, workItemStatus + (String.isBlank(sfItemStatus)?'':' / ' + sfItemStatus) } );
				
				update pt;
			}
			else if (objectType == 'Requirement__c')
			{
				Requirement__c pbl = [SELECT Id, Name, Status__c FROM Requirement__c WHERE Id = :workItemId];
				pbl.Status__c = workItemStatus2pblStage(workItemStatus, sfItemStatus);

	       		updatedDetails.isSuccess = true;
	        	updatedDetails.message = String.format( '{0} was moved successfully to {1}', new List<String>{ pbl.Name, workItemStatus + (String.isBlank(sfItemStatus)?'':' / ' + sfItemStatus) } );
				
				update pbl;
			}
			else
			{
				updatedDetails.message = 'Invalid or unsupported id ' + workItemId;
			}			
		}
		catch(Exception e)
		{
			updatedDetails.isSuccess = false;
			updatedDetails.message = e.getMessage();
		}
		
        return updatedDetails;
    }
}