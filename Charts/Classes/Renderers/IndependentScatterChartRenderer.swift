//
//  IndependentScatterChartRenderer.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//  derived from ScatterChart by Gerard J. Cerchio
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics
import UIKit

@objc
public protocol IndependentScatterChartRendererDelegate
{
    func scatterChartRendererData(renderer: IndependentScatterChartRenderer) -> IndependentScatterChartData!
    func scatterChartRenderer(renderer: IndependentScatterChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    func scatterChartDefaultRendererValueFormatter(renderer: IndependentScatterChartRenderer) -> NSNumberFormatter!
    func scatterChartRendererChartYMax(renderer: IndependentScatterChartRenderer) -> Double
    func scatterChartRendererChartYMin(renderer: IndependentScatterChartRenderer) -> Double
    func scatterChartRendererChartXMax(renderer: IndependentScatterChartRenderer) -> Double
    func scatterChartRendererChartXMin(renderer: IndependentScatterChartRenderer) -> Double
    func scatterChartRendererMaxVisibleValueCount(renderer: IndependentScatterChartRenderer) -> Int
}

public class IndependentScatterChartRenderer: ChartDataRendererBase
{
    public weak var delegate: IndependentScatterChartRendererDelegate?
    
    public init(delegate: IndependentScatterChartRendererDelegate?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.delegate = delegate
    }
    
    public override func drawData(#context: CGContext)
    {
        var scatterData = delegate!.scatterChartRendererData(self)
        
        if (scatterData === nil)
        {
            return
        }
        
        for (var i = 0; i < scatterData.dataSetCount; i++)
        {
            var set = scatterData.getDataSetByIndex(i)
            
            if (set !== nil && set!.isVisible)
            {
                drawDataSet(context: context, dataSet: set as! IndependentScatterChartDataSet)
            }
        }
    }
    
    private var _lineSegments = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    internal func drawDataSet(#context: CGContext, dataSet: IndependentScatterChartDataSet)
    {
        var trans = delegate!.scatterChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        
        var phaseX = _animator.phaseX
        var phaseY = _animator.phaseY
        
        var entries = dataSet.yVals
        
        var shapeSize = dataSet.scatterShapeSize
        var shapeHalf = shapeSize / 2.0
        
        var point = CGPoint()
        
        var valueToPixelMatrix = trans.valueToPixelMatrix
        
        var shape = dataSet.scatterShape
        
        CGContextSaveGState(context)
        
        for (var j = 0, count = Int(min(ceil(CGFloat(entries.count) * _animator.phaseX), CGFloat(entries.count))); j < count; j++)
        {
            var e = entries[j];
            point.x = CGFloat(e.xIndex);
            point.y = CGFloat(e.value) * phaseY;
            point = CGPointApplyAffineTransform(point, valueToPixelMatrix);
            
            if (!viewPortHandler.isInBoundsLeft(point.x) || !viewPortHandler.isInBoundsY(point.y))
            {
                continue
            }
            
            if (shape == .Square)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                var rect = CGRect()
                rect.origin.x = point.x - shapeHalf
                rect.origin.y = point.y - shapeHalf
                rect.size.width = shapeSize
                rect.size.height = shapeSize
                CGContextFillRect(context, rect)
            }
            else if (shape == .Circle)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                var rect = CGRect()
                rect.origin.x = point.x - shapeHalf
                rect.origin.y = point.y - shapeHalf
                rect.size.width = shapeSize
                rect.size.height = shapeSize
                CGContextFillEllipseInRect(context, rect)
            }
            else if (shape == .Cross)
            {
                CGContextSetStrokeColorWithColor(context, dataSet.colorAt(j).CGColor)
                _lineSegments[0].x = point.x - shapeHalf
                _lineSegments[0].y = point.y
                _lineSegments[1].x = point.x + shapeHalf
                _lineSegments[1].y = point.y
                CGContextStrokeLineSegments(context, _lineSegments, 2)
                
                _lineSegments[0].x = point.x
                _lineSegments[0].y = point.y - shapeHalf
                _lineSegments[1].x = point.x
                _lineSegments[1].y = point.y + shapeHalf
                CGContextStrokeLineSegments(context, _lineSegments, 2)
            }
            else if (shape == .Triangle)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                
                // create a triangle path
                CGContextBeginPath(context)
                CGContextMoveToPoint(context, point.x, point.y - shapeHalf)
                CGContextAddLineToPoint(context, point.x + shapeHalf, point.y + shapeHalf)
                CGContextAddLineToPoint(context, point.x - shapeHalf, point.y + shapeHalf)
                CGContextClosePath(context)
                
                CGContextFillPath(context)
            }
            else if (shape == .Custom)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                
                var customShape = dataSet.customScatterShape
                
                if (customShape === nil)
                {
                    return
                }
                
                // transform the provided custom path
                CGContextSaveGState(context)
                CGContextTranslateCTM(context, -point.x, -point.y)
                
                CGContextBeginPath(context)
                CGContextAddPath(context, customShape)
                CGContextFillPath(context)
                
                CGContextRestoreGState(context)
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(#context: CGContext)
    {
        var scatterData = delegate!.scatterChartRendererData(self)
        if (scatterData === nil)
        {
            return
        }
        
        var defaultValueFormatter = delegate!.scatterChartDefaultRendererValueFormatter(self);
        var lastPoint = CGPoint();
        var lastIndex = 0;
        
        // if values are drawn
        if (scatterData.yValCount < Int(ceil(CGFloat(delegate!.scatterChartRendererMaxVisibleValueCount(self)) * viewPortHandler.scaleX)))
        {
            var dataSets = scatterData.dataSets as! [IndependentScatterChartDataSet]
            
            for (var i = 0; i < scatterData.dataSetCount; i++)
            {
                var dataSet = dataSets[i]
                
                if (!dataSet.isDrawValuesEnabled)
                {
                    continue
                }
                
                var valueFont = dataSet.valueFont
                var valueTextColor = dataSet.valueTextColor
                
                var formatter = dataSet.valueFormatter
                if (formatter === nil)
                {
                    formatter = defaultValueFormatter
                }
                
                var entries = dataSet.yVals
                
                var positions = delegate!.scatterChartRenderer(self, transformerForAxis: dataSet.axisDependency).generateTransformedValuesScatter(entries, phaseY: _animator.phaseY)
                
                var shapeSize = dataSet.scatterShapeSize;
                var lineHeight = valueFont.lineHeight;
                var lineYoffset = shapeSize + lineHeight;
                
                if ( dataSet.drawLinesEnabled )
                {
                    CGContextSaveGState(context);
                }
                for (var j = 0, count = Int(ceil(CGFloat(positions.count) * _animator.phaseX)); j < count; j++)
                {
                    // make sure the lines don't do bad things outside bounds
                    if ((!viewPortHandler.isInBoundsLeft(positions[j].x)
                        || !viewPortHandler.isInBoundsY(positions[j].y)))
                    {
                        continue
                    }
                    
                    var val = (Double)(j);
                    if ( !dataSet.valueIsIndex )
                    {
                        val = entries[j].value;
                    }
                    
                    var text = formatter!.stringFromNumber(val);
                    var point = CGPoint(x: positions[j].x, y: positions[j].y - shapeSize - lineHeight);
                    
                    ChartUtils.drawText(context: context, text: text!, point: point, align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor]);
                    
                    if (  ( dataSet.drawLinesEnabled )   &&
                          ( j != 0 )              &&
                          ( j == lastIndex + 1 )  &&
                          ( viewPortHandler.isInBoundsRight( point.x ) ) )
                    {
                        CGContextSetStrokeColorWithColor(context, dataSet.colorAt(i).CGColor);
                        CGContextMoveToPoint( context, lastPoint.x, lastPoint.y + lineYoffset );
                        CGContextAddLineToPoint( context, point.x, point.y + lineYoffset );
                        
                        lastPoint = point;
                        lastIndex = j;
                    }
                    else
                    {
                        lastPoint = point;
                        lastIndex = j;
                    }
                }
                
                if ( dataSet.drawLinesEnabled )
                {
                    CGContextStrokePath( context );
                    CGContextRestoreGState(context);
                }
            }
            
        }
    }
    
   
    public override func drawExtras(#context: CGContext )
    {
        
    }
    
    public override func drawHighlighted(#context: CGContext, indices: [ChartHighlight])
    {
        var scatterData = delegate!.scatterChartRendererData(self)
        var chartXMax = delegate!.scatterChartRendererChartXMax(self)
        var chartYMax = delegate!.scatterChartRendererChartYMax(self)
        var chartYMin = delegate!.scatterChartRendererChartYMin(self)
        
        CGContextSaveGState(context)
        
        var pts = [CGPoint](count: 4, repeatedValue: CGPoint())
        
        for (var i = 0; i < indices.count; i++)
        {
            var set = scatterData.getDataSetByIndex(indices[i].dataSetIndex) as! IndependentScatterChartDataSet!
            
            if (set === nil || !set.isHighlightEnabled)
            {
                continue
            }
            
            CGContextSetStrokeColorWithColor(context, set.highlightColor.CGColor)
            CGContextSetLineWidth(context, set.highlightLineWidth)
            if (set.highlightLineDashLengths != nil)
            {
                CGContextSetLineDash(context, set.highlightLineDashPhase, set.highlightLineDashLengths!, set.highlightLineDashLengths!.count)
            }
            else
            {
                CGContextSetLineDash(context, 0.0, nil, 0)
            }
            
            var xIndex = indices[i].xIndex; // get the x-position
            
            if (CGFloat(xIndex) > CGFloat(chartXMax) * _animator.phaseX)
            {
                continue
            }
            
            let yVal = set.yValForXIndex(xIndex)
            if (yVal.isNaN)
            {
                continue
            }
            
            var y = CGFloat(yVal) * _animator.phaseY; // get the y-position
            
            pts[0] = CGPoint(x: CGFloat(xIndex), y: CGFloat(chartYMax))
            pts[1] = CGPoint(x: CGFloat(xIndex), y: CGFloat(chartYMin))
            pts[2] = CGPoint(x: 0.0, y: y)
            pts[3] = CGPoint(x: CGFloat(chartXMax), y: y)
            
            var trans = delegate!.scatterChartRenderer(self, transformerForAxis: set.axisDependency)
            
            trans.pointValuesToPixel(&pts)
            
            // draw the highlight lines
            CGContextStrokeLineSegments(context, pts, pts.count)
        }
        
        CGContextRestoreGState(context)
    }
}