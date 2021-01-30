//
//  LocationPickerTableViewCell.swift
//  LocationPicker
//
//  Created by Idan Moshe on 30/01/2021.
//

import UIKit

class LocationPickerTableViewCell: UITableViewCell {
    
    deinit {
        debugPrint("Deallocating \(self)")
        self.imageView?.image = nil
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.imageView?.image = UIImage(systemName: "location")
        self.imageView?.layer.masksToBounds = true
        self.imageView?.clipsToBounds = true
        self.imageView?.backgroundColor = .systemGroupedBackground
        self.imageView?.layer.cornerRadius = (self.imageView?.frame.size.height)!/2.0
        self.imageView?.isHidden = false
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
