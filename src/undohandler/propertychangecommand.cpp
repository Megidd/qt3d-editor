/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the Qt3D Editor of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:GPL-EXCEPT$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3 as published by the Free Software
** Foundation with exceptions as appearing in the file LICENSE.GPL3-EXCEPT
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/
#include "propertychangecommand.h"

#include "editorscene.h"
#include "editorsceneitem.h"
#include "editorsceneitemmodel.h"
#include "undohandler.h"

#include <Qt3DCore/QEntity>
#include <Qt3DCore/QComponent>

PropertyChangeCommand::PropertyChangeCommand(EditorSceneItemModel *sceneModel,
                                             const QString &entityName,
                                             EditorSceneItemComponentsModel::EditorSceneItemComponentTypes componentType,
                                             const QString &propertyName,
                                             const QVariant &newValue,
                                             const QVariant &oldValue) :
    m_sceneModel(sceneModel),
    m_entityName(entityName),
    m_componentType(componentType),
    m_propertyName(propertyName.toLatin1()),
    m_newValue(newValue),
    m_oldValue(oldValue)
{
}

void PropertyChangeCommand::undo()
{
    if (isNonOp())
        return;
    QObject *object = getTargetObject();
    if (object) {
        object->setProperty(m_propertyName, m_oldValue);
        if (m_propertyName == QByteArrayLiteral("enabled")) {
            // Handle hiding/showing camera & light placeholder meshes
            m_sceneModel->scene()->handleEnabledChanged(qobject_cast<Qt3DCore::QEntity *>(object),
                                                        m_oldValue.toBool());
        }
    }
}

void PropertyChangeCommand::redo()
{
    if (isNonOp())
        return;
    QObject *object = getTargetObject();
    if (object) {
        object->setProperty(m_propertyName, m_newValue);
        if (m_propertyName == QByteArrayLiteral("enabled")) {
            // Handle hiding/showing camera & light placeholder meshes
            m_sceneModel->scene()->handleEnabledChanged(qobject_cast<Qt3DCore::QEntity *>(object),
                                                        m_newValue.toBool());
        }
    }
}

bool PropertyChangeCommand::mergeWith(const QUndoCommand *other)
{
    // TODO: Is this actually desirable functionality? This is clearly useful
    // TODO: when adjusting values via spinboxes or sliders, but might be unintuitive in
    // TODO: some cases, e.g. when you leave the control and come back to it for further
    // TODO: adjustments.

    // Can merge if both commands target same entity, component, and property
    if (id() == other->id()) {
        const PropertyChangeCommand *otherCommand = static_cast<const PropertyChangeCommand *>(other);
        if (otherCommand->m_sceneModel == m_sceneModel
                && otherCommand->m_entityName == m_entityName
                && otherCommand->m_componentType == m_componentType
                && otherCommand->m_propertyName == m_propertyName) {
            m_newValue = otherCommand->m_newValue;
            return true;
        }
    }
    return false;
}

int PropertyChangeCommand::id() const
{
    return UndoHandler::PropertyChangeCommandId;
}

bool PropertyChangeCommand::isNonOp() const
{
    return m_newValue == m_oldValue;
}

QObject *PropertyChangeCommand::getTargetObject()
{
    QModelIndex modelIndex = m_sceneModel->getModelIndexByName(m_entityName);
    EditorSceneItem *sceneItem = m_sceneModel->editorSceneItemFromIndex(modelIndex);
    QObject *object = nullptr;
    if (m_componentType == EditorSceneItemComponentsModel::GeneralEntity
            || m_componentType == EditorSceneItemComponentsModel::CameraEntity) {
        object = sceneItem->entity();
    } else {
        foreach (Qt3DCore::QComponent *component, sceneItem->entity()->components()) {
            if (sceneItem->componentsModel()->typeOfComponent(component) == m_componentType) {
                object = component;
                break;
            }
        }
    }
    return object;
}
