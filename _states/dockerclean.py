
def images_cleaned(name):
    """
    Removes all Docker images which are untagged.
    """

    ret = {'name': name, 'changes': {}, 'result': False, 'comment': ''}

    # Fetch a list of untagged images
    untagged_images = []
    for image in __salt__['docker.get_images'](all=False)['out']:
        if not image['RepoTags'] or image['RepoTags'][0] == '<none>:<none>':
            untagged_images.append(image['Id'])

    if not untagged_images:
        ret['result'] = True
        ret['comment'] = 'No untagged images found.'
        return ret

    if __opts__['test']:
        ret['comment'] = 'The state of "{0}" will be changed.'.format(name)
        ret['changes'] = {
            'old': '',
            'new': '{0} images will be removed.'.format(len(untagged_images)),
        }
        ret['result'] = None
        return ret

    # Remove the images
    for image_id in untagged_images:
        __salt__['docker.remove_image'](image_id)

    ret['comment'] = 'The state of "{0}" has been changed.'.format(name)
    ret['changes'] = {
        'old': '',
        'new': '{0} images have been removed.'.format(len(untagged_images)),
    }
    ret['result'] = True

    return ret
