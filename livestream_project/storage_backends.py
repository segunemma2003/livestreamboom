from storages.backends.s3boto3 import S3Boto3Storage

class StaticStorage(S3Boto3Storage):
    bucket_name = 'livestream-static'
    location = 'static'

class MediaStorage(S3Boto3Storage):
    bucket_name = 'livestream-media'
    location = 'media'
    file_overwrite = False