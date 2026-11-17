<?php
declare(strict_types=1);

namespace QueenOne\Connect\Model\System\Config\Backend;

use Magento\Framework\App\Config\Value;
use Magento\Framework\Exception\LocalizedException;
use QueenOne\Connect\Model\TrackingConfig;

class TagUrl extends Value
{
    public function beforeSave()
    {
        $url = trim((string) $this->getValue());
        if ($url !== '' && !TrackingConfig::isValidTagUrl($url)) {
            throw new LocalizedException(__('Enter an HTTPS Tag URL without credentials or a fragment.'));
        }
        $this->setValue($url);
        return parent::beforeSave();
    }
}
