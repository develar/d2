package ppt

import (
	"archive/zip"
	"bytes"
	_ "embed"
	"fmt"
	"image/png"
	"os"
)

// TODO: comments / references / assumptions
// TODO: update core files with metadata

type Presentation struct {
	Slides []*Slide
}

type Slide struct {
	Title       string
	Image       []byte
	ImageWidth  int
	ImageHeight int
	ImageTop    int
	ImageLeft   int
}

func NewPresentation() *Presentation {
	return &Presentation{}
}

func (p *Presentation) AddSlide(title string, pngContent []byte) error {
	src, err := png.Decode(bytes.NewReader(pngContent))
	if err != nil {
		return fmt.Errorf("error decoding PNG image: %v", err)
	}

	var width, height, top, left int
	srcSize := src.Bounds().Size()

	// compute the size and position to fit the slide
	if srcSize.X > srcSize.Y {
		width = IMAGE_WIDTH
		height = int(float64(width) * (float64(srcSize.X) / float64(srcSize.Y)))
		left = 0
		top = (IMAGE_HEIGHT - height) / 2
	} else {
		height = IMAGE_HEIGHT
		width = int(float64(height) * (float64(srcSize.X) / float64(srcSize.Y)))
		top = 0
		left = (IMAGE_WIDTH - width) / 2
	}

	p.Slides = append(p.Slides, &Slide{
		Title:       title,
		Image:       pngContent,
		ImageWidth:  width,
		ImageHeight: height,
		ImageTop:    top,
		ImageLeft:   left,
	})

	return nil
}

func (p *Presentation) SaveTo(filePath string) error {
	f, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer f.Close()
	zipFile := zip.NewWriter(f)
	defer zipFile.Close()

	copyPptxTemplateTo(zipFile)

	var slideFileNames []string
	for i, slide := range p.Slides {
		imageId := fmt.Sprintf("slide%dImage", i+1)
		slideFileName := fmt.Sprintf("slide%d", i+1)
		slideFileNames = append(slideFileNames, slideFileName)

		imageWriter, err := zipFile.Create(fmt.Sprintf("ppt/media/%s.png", imageId))
		if err != nil {
			return err
		}
		_, err = imageWriter.Write(slide.Image)
		if err != nil {
			return err
		}

		err = addFile(zipFile, fmt.Sprintf("ppt/slides/_rels/%s.xml.rels", slideFileName), getRelsSlideXml(imageId))
		if err != nil {
			return err
		}

		// TODO: center the image?
		err = addFile(
			zipFile,
			fmt.Sprintf("ppt/slides/%s.xml", slideFileName),
			getSlideXml(slide.Title, imageId, slide.ImageTop, slide.ImageLeft, slide.ImageWidth, slide.ImageHeight),
		)
		if err != nil {
			return err
		}
	}

	err = addFile(zipFile, "[Content_Types].xml", getContentTypesXml(slideFileNames))
	if err != nil {
		return err
	}

	err = addFile(zipFile, "ppt/_rels/presentation.xml.rels", getPresentationXmlRels(slideFileNames))
	if err != nil {
		return err
	}

	err = addFile(zipFile, "ppt/presentation.xml", getPresentationXml(slideFileNames))
	if err != nil {
		return err
	}

	return nil
}
