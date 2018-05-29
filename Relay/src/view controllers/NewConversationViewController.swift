//
//  NewConversationViewController.swift
//  Forsta
//
//  Created by Mark Descalzo on 5/24/18.
//  Copyright © 2018 Forsta. All rights reserved.
//

import UIKit
import CocoaLumberjack

class NewConversationViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, SlugCellDelegate {
    
    
    func deleteButtonTappedOnSlug(sender: Any) {
        print("a thing")
    }
    
    
    // Constants
    private let kMinInputHeight: CGFloat = 0.0
    private let kMaxInputHeight: CGFloat = 84.0
    
    private let kRecipientSectionIndex: Int = 0
    private let kTagSectionIndex: Int = 1
    
    private let kHiddenSectionIndex: Int = 0
    private let kMonitorSectionIndex: Int = 1
    
    private let kSelectorVisibleIndex: Int = 0
    private let kSelectorHiddenIndex: Int = 1
    
    // UI Elements
    @IBOutlet private weak var searchBar: UISearchBar?
    @IBOutlet private weak var contactTableView: UITableView?
    @IBOutlet private weak var slugCollectionView: UICollectionView?
    @IBOutlet private weak var exitButton: UIBarButtonItem?
    @IBOutlet private weak var goButton: UIBarButtonItem?
    @IBOutlet private weak var slugViewHeightConstraint: NSLayoutConstraint?
    @IBOutlet private weak var searchInfoLabel: UILabel?
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshContentFromSource), for: .valueChanged)
        return control
    }()
    
    private let uiDBConnection: YapDatabaseConnection = TSStorageManager.shared().database().newConnection()
    private let searchDBConnection: YapDatabaseConnection = TSStorageManager.shared().database().newConnection()
    
    private var tagMappings: YapDatabaseViewMappings?
    
    // Properties
    private var selectedSlugs: Array<String> = Array()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.slugViewHeightConstraint?.constant = kMinInputHeight
        self.goButton?.tintColor = ForstaColors.mediumLightGreen()
        
        self.searchBar?.placeholder = NSLocalizedString("SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT", comment: "")
        self.searchInfoLabel?.text = NSLocalizedString("SEARCH_HELP_STRING", comment:"Informational string for tag lookups.")
        
        self.view.backgroundColor = ForstaColors.white
        
        // Refresh control handling
        let refreshView = UIView()
        self.contactTableView?.insertSubview(refreshView, at: 0)
        refreshView.addSubview(self.refreshControl)
        
        // Set the mappings
        self.changeMappingsGroup(groups: [FLVisibleRecipientGroup, FLActiveTagsGroup ])
        
        self.updateGoButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.updateContactsView()
        
        self.uiDBConnection.beginLongLivedReadTransaction()
        self.uiDBConnection.read { transaction in
            self.tagMappings?.update(with: transaction)
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(yapDatabaseModified),
                                               name: NSNotification.Name.YapDatabaseModified,
                                               object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        self.uiDBConnection.endLongLivedReadTransaction()
        
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - CollectionView delegate/datasource methods
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (self.selectedSlugs.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: SlugCell = self.slugCollectionView?.dequeueReusableCell(withReuseIdentifier: "SlugCell", for: indexPath) as! SlugCell
        
        cell.slug = self.selectedSlugs[indexPath.row]
        cell.delegate = self
        
        return cell
    }

//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        <#code#>
//    }
    
    // MARK: - TableView delegate/datasource methods
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! FLDirectoryCell
        
        let aThing = self.objectForIndexPath(indexPath: indexPath)
        
        if aThing.isKind(of: SignalRecipient.classForCoder()) {
            let recipient = aThing as! SignalRecipient
            
            DispatchQueue.global(qos: .default).async {
                cell.configureCell(withContact: recipient)
            }
            if (self.selectedSlugs.contains(recipient.flTag.displaySlug)) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else if aThing.isKind(of: FLTag.classForCoder()) {
            let aTag = aThing as! FLTag
            
            DispatchQueue.global(qos: .default).async {
                cell.configureCell(with: aTag)
            }
            if (self.selectedSlugs.contains(aTag.displaySlug)) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else {
            return UITableViewCell()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var tagSlug: String
        
        let aThing: NSObject = self.objectForIndexPath(indexPath: indexPath)
        
        if aThing.isKind(of: SignalRecipient.classForCoder()) {
            let recipient = aThing as! SignalRecipient
            tagSlug = recipient.flTag.displaySlug
        } else if aThing.isKind(of: FLTag.classForCoder()) {
            let aTag = aThing as! FLTag
            tagSlug = aTag.displaySlug
        } else {
            return
        }
        
        if (self.selectedSlugs.contains(tagSlug)) {
            self.removeSlug(slug: tagSlug)
        } else {
            self.addSlug(slug: tagSlug)
        }
        
        self.contactTableView?.reloadRows(at: [indexPath], with: .automatic)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        let number: NSNumber = NSNumber(value: (self.tagMappings?.numberOfSections())!)
        return Int(number)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let number: NSNumber = NSNumber(value: (self.tagMappings?.numberOfItems(inSection: UInt(section)))!)
        return Int(number)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.tableView(tableView, numberOfRowsInSection: section) > 0 {
            if section == kRecipientSectionIndex {
                return NSLocalizedString("THREAD_SECTION_HIDDEN", comment: "")
            } else if section == kTagSectionIndex {
                return NSLocalizedString("THREAD_SECTION_MONITORS", comment: "")
            }
        }
        return nil
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    internal func yapDatabaseModified(notification: Notification) {
        let notfications = self.uiDBConnection.beginLongLivedReadTransaction()
        
        var sectionChanges = NSArray()
        var rowChanges = NSArray()
        
        let dbViewConnection: YapDatabaseViewConnection = self.uiDBConnection.ext(FLFilteredTagDatabaseViewExtensionName) as! YapDatabaseViewConnection
        dbViewConnection.getSectionChanges(&sectionChanges, rowChanges: &rowChanges, for: notfications, with: self.tagMappings!)
        
        // No related changes, bail...
        if (sectionChanges.count == 0 && rowChanges.count == 0) {
            return
        }
        
        self.contactTableView?.beginUpdates()
        
        for sectionChange in sectionChanges {
            let change = sectionChange as! YapDatabaseViewSectionChange
            switch change.type {
            case .insert:
                self.contactTableView?.insertSections(NSIndexSet(index: Int(change.index)) as IndexSet, with: .automatic)
            case .delete:
                self.contactTableView?.deleteSections(NSIndexSet(index: Int(change.index)) as IndexSet, with: .automatic)
            case .move:
                break
            case .update:
                self.contactTableView?.reloadSections(NSIndexSet(index: Int(change.index)) as IndexSet, with: .automatic)
            }
        }
        
        for rowChange in rowChanges {
            let change = rowChange as! YapDatabaseViewRowChange
            switch change.type {
                
            case .insert:
                self.contactTableView?.insertRows(at: [ change.newIndexPath! ], with: .automatic)
            case .delete:
                self.contactTableView?.deleteRows(at: [ change.indexPath! ], with: .automatic)
            case .move:
                self.contactTableView?.deleteRows(at: [ change.indexPath! ], with: .automatic)
                self.contactTableView?.insertRows(at: [ change.newIndexPath! ], with: .automatic)
            case .update:
                self.contactTableView?.reloadRows(at: [ change.indexPath! ], with: .automatic)
            }
        }
        self.contactTableView?.endUpdates()
    }
    
    // MARK: - UI Actions
    @IBAction func didPressGoButton(sender: Any) {
        var threadSlugs = String()
        
        for slug in self.selectedSlugs {
            if threadSlugs.count == 0 {
                threadSlugs.append(slug)
            } else {
                threadSlugs.append(" + \(slug)")
            }
        }
        CCSMCommManager.asyncTagLookup(with: threadSlugs,
                                       success: { results in
                                        self.storeUsersIn(results: results as NSDictionary)
                                        self.buildThreadWith(results: results as NSDictionary)
        },
                                       failure: { error in
                                        DDLogDebug(String(format: "Tag Lookup failed with error: %@", error.localizedDescription))
                                        DispatchQueue.main.async {
                                            let alert = UIAlertController(title: nil,
                                                                          message: NSLocalizedString("ERROR_DESCRIPTION_SERVER_FAILURE", comment: ""),
                                                                          preferredStyle: .actionSheet)
                                            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                                                          style: .default,
                                                                          handler: nil))
                                            self.navigationController?.present(alert, animated: true, completion: nil)
                                        }

        })
        
    }

    @IBAction func didPressExitButton(sender: Any) {
        if (self.searchBar?.isFirstResponder)! {
            self.searchBar?.resignFirstResponder()
        }
        self.navigationController?.dismiss(animated: true, completion: { })
    }

    
    // MARK: - Thread creation methods
    private func storeUsersIn(results: NSDictionary) {
        DispatchQueue.global(qos: .background).async {
            let usersIds: NSArray = results.object(forKey: "userids") as! NSArray
            
            for uid in usersIds {
                Environment.getCurrent().contactsManager.recipient(withUserId: uid as! String)
            }
        }
    }
    
    private func buildThreadWith(results: NSDictionary) {
        let userIds = results.object(forKey: "userids") as! NSArray
        
        // Verify myself is included
        if !(userIds.contains(TSAccountManager.sharedInstance().myself?.uniqueId as Any)) {
            // If not, add self and run again
            let pretty: NSMutableString = results.object(forKey: "pretty") as! NSMutableString
            pretty.appendFormat(" + @%@", (TSAccountManager.sharedInstance().myself?.flTag.slug)!)
            
            CCSMCommManager.asyncTagLookup(with: pretty as String, success: { newResults in
                self.buildThreadWith(results: newResults as NSDictionary)
            }, failure: { error in
                DDLogDebug(String(format: "Tag Lookup failed with error: %@", error.localizedDescription))
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: nil,
                                                  message: NSLocalizedString("ERROR_DESCRIPTION_SERVER_FAILURE", comment: ""),
                                                  preferredStyle: .actionSheet)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                                  style: .default,
                                                  handler: nil))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                }
            })
        } else {
            // build thread and go
            self.navigationController?.dismiss(animated: true, completion: {
                let thread = TSThread.getOrCreateThread(withParticipants: userIds as! [String])
                thread.type = FLThreadTypeConversation
                thread.prettyExpression = results.object(forKey: "pretty") as! String
                thread.universalExpression = results.object(forKey: "universal") as! String
                thread.save()
                
                // Spin off background process to pull in participants
                DispatchQueue.global(qos: .background).async {
                    for uid in userIds {
                        Environment.getCurrent().contactsManager.updateRecipient(uid as! String)
                    }
                }
                Environment.messageGroup(thread)
            })
        }
    }

    // MARK: - Private worker methods
    private func updateFilteredMappings() {
        let filterString = self.searchBar?.text?.lowercased()
        
        let filtering = YapDatabaseViewFiltering.withObjectBlock { (transaction, group, collection, key, object) -> Bool in
            let obj: NSObject = object as! NSObject
            if obj.isKind(of: SignalRecipient.classForCoder()) || obj.isKind(of: FLTag.classForCoder()) {
                if (filterString?.count)! > 0 {
                    if obj.isKind(of: FLTag.classForCoder()) {
                        let aTag: FLTag = obj as! FLTag
                        return ((aTag.displaySlug.lowercased() as NSString).contains(filterString!) ||
                            (aTag.slug.lowercased() as NSString).contains(filterString!) ||
                            (aTag.tagDescription!.lowercased() as NSString).contains(filterString!) ||
                            (aTag.orgSlug.lowercased() as NSString).contains(filterString!))
                        
                    } else if obj.isKind(of: SignalRecipient.classForCoder()) {
                        let recipient: SignalRecipient = obj as! SignalRecipient
                        return ( (recipient.fullName.lowercased() as NSString).contains(filterString!) ||
                            (recipient.flTag.displaySlug.lowercased() as NSString).contains(filterString!) ||
                            (recipient.orgSlug.lowercased() as NSString).contains(filterString!))
                    } else {
                        return false
                    }
                } else {
                    return true
                }
            }
            return false
        }
        self.searchDBConnection.readWrite { transaction in
            let filteredView: YapDatabaseFilteredViewTransaction = transaction.ext(FLFilteredTagDatabaseViewExtensionName) as! YapDatabaseFilteredViewTransaction
            filteredView.setFiltering(filtering, versionTag: filterString)
        }
        self.updateContactsView()
    }
    
    private func removeSlug(slug: String) {
        var slugString = slug as String
        
        if !(slug.substring(to:  1) == "@") {
            slugString = String.init(format: "@%@", slug)
        }
        
        let index = self.selectedSlugs.index(of: slugString)
        self.selectedSlugs.remove(at: index!)
        
        DispatchQueue.main.async {
            // Refresh collection view
            self.slugCollectionView?.reloadData()
            self.updateGoButton()
        }
    }
    
    private func addSlug(slug: String) {
        var slugString = slug as String
        
        if !(slug.substring(to:  1) == "@") {
            slugString = String.init(format: "@%@", slug)
        }
        
        self.selectedSlugs.append(slugString)
        
        DispatchQueue.main.async {
            // Refresh collection view
            self.slugCollectionView?.reloadData()
            self.updateGoButton()
        }
    }
    
    private func objectForIndexPath(indexPath: IndexPath) -> NSObject {
        var object = NSObject()
        
        self.uiDBConnection.read { transaction in
            let viewTransaction: YapDatabaseViewTransaction = transaction.ext(FLFilteredTagDatabaseViewExtensionName) as! YapDatabaseViewTransaction
            object = viewTransaction.object(at: indexPath, with: self.tagMappings!) as! NSObject
        }
        return object
    }
    
    @objc private func refreshContentFromSource() {
        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
            Environment.getCurrent().contactsManager.refreshCCSMRecipients()
            self.refreshControl.endRefreshing()
        }
    }
    
    private func updateGoButton() {
        DispatchQueue.main.async {
            if self.selectedSlugs.count == 0 {
                self.goButton?.isEnabled = false
            } else {
                self.goButton?.isEnabled = true
            }
        }
    }
    
    private func updateContactsView() {
        DispatchQueue.main.async {
            if self.tagMappings?.numberOfItemsInAllGroups() == 0 {
                self.searchInfoLabel?.isHidden = false
                self.contactTableView?.isHidden = true
            } else {
                self.searchInfoLabel?.isHidden = true
                self.contactTableView?.isHidden = false
            }
            self.contactTableView?.reloadData()
        }
    }
    
    private func changeMappingsGroup(groups: Array<String>) {
        self.tagMappings = YapDatabaseViewMappings(groups: groups , view: FLFilteredTagDatabaseViewExtensionName)
        
        for group in groups {
            self.tagMappings?.isReversed(forGroup: group)
        }
        
        DispatchQueue.main.async {
            self.uiDBConnection.read { transaction in
                self.tagMappings?.update(with: transaction)
            }
            self.updateContactsView()
        }
    }
}

// Source: https://stackoverflow.com/questions/39677330/how-does-string-substring-work-in-swift
extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return substring(from: fromIndex)
    }
    
    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return substring(to: toIndex)
    }
    
    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return substring(with: startIndex..<endIndex)
    }
}
