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
      let alertView: CustomAlert
      switch myAlert.alertType {
      case .annotationSelected:
        alertView = CustomAlert(
          presentAlert: $myAlert.isAlert,
          alertModel: myAlert.alertType.model,
          leftButtonAction: {},
          rightButtonAction: {
            if let marker = viewModel.selectedMarker {
              viewModel.removeLocation(marker.id)
            }
          }
        )
      case .custom(let alert, let leftAction, let rightAction):
        alertView = CustomAlert(
          presentAlert: $myAlert.isAlert,
          alertModel: alert,
          leftButtonAction: leftAction,
          rightButtonAction: rightAction
        )
      case .customThreeButton(let alert, let leftAction, let middleAction, let rightAction):
        alertView = CustomAlert(
          presentAlert: $myAlert.isAlert,
          alertModel: alert,
          leftButtonAction: leftAction,
          middleButtonAction: middleAction,
          rightButtonAction: rightAction
        )
      case .loggedOut, .authRequired:
        alertView = CustomAlert(
          presentAlert: $myAlert.isAlert,
          alertModel: myAlert.alertType.model
        )
      case .deletePolygon(let id):
        alertView = CustomAlert(
          presentAlert: $myAlert.isAlert,
          alertModel: myAlert.alertType.model,
          leftButtonAction: {},
          rightButtonAction: {
            viewModel.deletePolygonAndRefresh(id)
          }
        )
      }
      return AnyView(
        alertView
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
          .accessibilityIdentifier("map.alert.host")
      )
    }
    else {
      return AnyView(EmptyView())
    }
  }
}
