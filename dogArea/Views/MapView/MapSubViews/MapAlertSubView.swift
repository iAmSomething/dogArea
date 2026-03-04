//
//  MapAlertSubView.swift
//  dogArea
//
//  Created by 김태훈 on 10/20/23.
//

import SwiftUI

struct MapAlertSubView: View {
  @ObservedObject var viewModel: MapViewModel
  @ObservedObject var myAlert: CustomAlertViewModel
  var body: some View {
    if myAlert.isAlert {
      var ca : CustomAlert
      switch myAlert.alertType {
      case .annotationSelected(_) :
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model,
                         leftButtonAction: {
        },rightButtonAction: {
          if let marker = viewModel.selectedMarker {
            viewModel.removeLocation(marker.id)
          }})
      case .custom(let alert, let leftAction, let rightAction) :
          ca = CustomAlert(presentAlert: $myAlert.isAlert, alertModel: alert , leftButtonAction: leftAction, rightButtonAction: rightAction)
      case .customThreeButton(let alert, let leftAction, let middleAction, let rightAction):
        ca = CustomAlert(
            presentAlert: $myAlert.isAlert,
            alertModel: alert,
            leftButtonAction: leftAction,
            middleButtonAction: middleAction,
            rightButtonAction: rightAction
        )
      case .logOut:
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model)
      case .deletePolygon(let id):
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model, leftButtonAction: {viewModel.deletePolygonAndRefresh(id)
        },rightButtonAction: {
          
        })
      }
      return AnyView(ca)
    }
    else {
      return AnyView(EmptyView())
    }
  }
}
